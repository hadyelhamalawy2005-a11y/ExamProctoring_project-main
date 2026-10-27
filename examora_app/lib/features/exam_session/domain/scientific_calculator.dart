import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Whether angles are in degrees or radians.
enum AngleMode {
  /// A full turn is 360.
  degrees,

  /// A full turn is 2π.
  radians,
}

/// Why an expression has no value.
enum CalcError {
  /// There is nothing to calculate.
  empty,

  /// The expression is not well formed (a missing bracket, a misplaced operator, a word that is not a function).
  syntax,

  /// Division by zero.
  divisionByZero,

  /// A function was given a number outside its domain (the square root of a negative, ln of 0, asin of 2, tan of 90°).
  domain,

  /// The answer is too large to represent.
  overflow,

  /// The expression is longer than the allowed length.
  tooLong,

  /// Brackets are nested more deeply than the allowed depth.
  tooDeep,
}

/// What an expression evaluates to.
@immutable
sealed class CalcResult {
  /// Creates a result.
  const CalcResult();
}

/// A number.
final class CalcValue extends CalcResult {
  /// Creates a value.
  const CalcValue(this.value);

  /// The number.
  final double value;
}

/// No number, and why.
final class CalcFailure extends CalcResult {
  /// Creates a failure.
  const CalcFailure(this.error);

  /// Why.
  final CalcError error;
}

/// A scientific calculator's evaluator, written for this app.
///
/// It reads the expression with a small grammar of its own (numbers, + - × ÷ ^ ! %, brackets, a fixed list of functions and
/// constants) and nothing else. There is no `eval`, no scripting and no way to name a variable or call anything that is
/// not on the list: any other word, symbol or character is a syntax error. Length and nesting are capped so a hostile
/// string cannot exhaust time or stack.
abstract final class ScientificCalculator {
  /// The longest expression accepted.
  static const int maxLength = 200;

  /// The deepest bracket nesting accepted.
  static const int maxDepth = 40;

  /// The functions that exist.
  static const Set<String> functions = {'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'ln', 'log', 'abs', 'exp'};

  /// Evaluates [expression]. Trigonometry uses [mode].
  static CalcResult evaluate(String expression, {AngleMode mode = AngleMode.degrees}) {
    final text = expression.trim();
    if (text.isEmpty) return const CalcFailure(CalcError.empty);
    if (text.length > maxLength) return const CalcFailure(CalcError.tooLong);
    try {
      final tokens = _tokenize(_normalize(text));
      if (tokens.isEmpty) return const CalcFailure(CalcError.empty);
      final parser = _Parser(tokens, mode);
      final value = parser.parseAll();
      return CalcValue(_tidy(value));
    } on _CalcException catch (exception) {
      return CalcFailure(exception.error);
    }
  }

  /// A number for the display: whole numbers without ".0", otherwise 12 significant digits without trailing zeros.
  static String format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) return value.toInt().toString();
    var text = value.toStringAsPrecision(12);
    if (text.contains('e')) {
      final parts = text.split('e');
      var mantissa = parts[0];
      if (mantissa.contains('.')) mantissa = mantissa.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return '${mantissa}e${parts[1].replaceFirst('+', '')}';
    }
    if (text.contains('.')) text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return text;
  }

  /// Removes floating-point dust (sin 180° is 0, not 1.2e-16) and keeps 12 significant digits.
  static double _tidy(double value) {
    if (value.abs() < 1e-12) return 0;
    return double.parse(value.toStringAsPrecision(12));
  }

  /// Arabic-Indic digits and the Arabic decimal separator become their ASCII forms; nothing else is changed.
  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x066B) {
        buffer.write('.');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    var index = 0;
    while (index < text.length) {
      final char = text[index];
      final code = char.codeUnitAt(0);
      if (char == ' ' || char == '	' || char == ' ') {
        index++;
      } else if (code >= 0x30 && code <= 0x39 || char == '.') {
        var end = index;
        var dots = 0;
        while (end < text.length &&
            (text[end].codeUnitAt(0) >= 0x30 && text[end].codeUnitAt(0) <= 0x39 || text[end] == '.')) {
          if (text[end] == '.') dots++;
          end++;
        }
        final literal = text.substring(index, end);
        if (dots > 1 || literal == '.') throw const _CalcException(CalcError.syntax);
        final number = double.tryParse(literal);
        if (number == null) throw const _CalcException(CalcError.syntax);
        if (number.isInfinite) throw const _CalcException(CalcError.overflow);
        // Two numbers side by side ("2 3") are not a multiplication, they are a typing mistake.
        if (tokens.isNotEmpty && tokens.last.kind == _Kind.number) throw const _CalcException(CalcError.syntax);
        tokens.add(_Token.number(number));
        index = end;
      } else if (_isLetter(code)) {
        var end = index;
        while (end < text.length && _isLetter(text[end].codeUnitAt(0))) {
          end++;
        }
        final word = text.substring(index, end).toLowerCase();
        if (functions.contains(word)) {
          tokens.add(_Token.function(word));
        } else if (word == 'pi') {
          tokens.add(_Token.constant(math.pi));
        } else if (word == 'e') {
          tokens.add(_Token.constant(math.e));
        } else {
          // Not a function and not a constant: it names nothing, so there is nothing to look up or run.
          throw const _CalcException(CalcError.syntax);
        }
        index = end;
      } else {
        switch (char) {
          case '+':
            tokens.add(const _Token.symbol('+'));
          case '-' || '−' || '–':
            tokens.add(const _Token.symbol('-'));
          case '*' || '×' || '⋅' || '·':
            tokens.add(const _Token.symbol('*'));
          case '/' || '÷':
            tokens.add(const _Token.symbol('/'));
          case '^':
            tokens.add(const _Token.symbol('^'));
          case '!':
            tokens.add(const _Token.symbol('!'));
          case '%':
            tokens.add(const _Token.symbol('%'));
          case '(':
            tokens.add(const _Token.symbol('('));
          case ')':
            tokens.add(const _Token.symbol(')'));
          case 'π':
            tokens.add(_Token.constant(math.pi));
          case '√':
            tokens.add(const _Token.function('sqrt'));
          default:
            throw const _CalcException(CalcError.syntax);
        }
        index++;
      }
    }
    return tokens;
  }

  static bool _isLetter(int code) => (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
}

final class _CalcException implements Exception {
  const _CalcException(this.error);

  final CalcError error;
}

enum _Kind { number, constant, function, symbol }

final class _Token {
  const _Token.number(double this.number) : kind = _Kind.number, name = '';
  const _Token.constant(double this.number) : kind = _Kind.constant, name = '';
  const _Token.function(this.name) : kind = _Kind.function, number = null;
  const _Token.symbol(this.name) : kind = _Kind.symbol, number = null;

  final _Kind kind;
  final String name;
  final double? number;

  bool isSymbol(String symbol) => kind == _Kind.symbol && name == symbol;

  /// True when this token can begin a value (so it may follow a value as an implied multiplication).
  bool get startsValue => kind == _Kind.number || kind == _Kind.constant || kind == _Kind.function || isSymbol('(');
}

/// Recursive descent over the tokens.
///
///   expression := term (("+" | "-") term)*
///   term       := unary (("*" | "/" | implied multiplication) unary)*
///   unary      := ("-" | "+") unary | power
///   power      := postfix ("^" unary)?              (right-associative, so 2^3^2 = 2^9)
///   postfix    := primary ("!" | "%")*
///   primary    := number | constant | "(" expression ")" | function "(" expression ")"
final class _Parser {
  _Parser(this._tokens, this._mode);

  final List<_Token> _tokens;
  final AngleMode _mode;
  var _position = 0;
  var _depth = 0;

  double parseAll() {
    final value = _expression();
    if (_position != _tokens.length) throw const _CalcException(CalcError.syntax);
    return value;
  }

  _Token? get _peek => _position < _tokens.length ? _tokens[_position] : null;

  double _expression() {
    var value = _term();
    while (_peek != null && (_peek!.isSymbol('+') || _peek!.isSymbol('-'))) {
      final plus = _peek!.isSymbol('+');
      _position++;
      final right = _term();
      value = plus ? value + right : value - right;
      _checkFinite(value);
    }
    return value;
  }

  double _term() {
    var value = _unary();
    while (_peek != null) {
      final token = _peek!;
      if (token.isSymbol('*')) {
        _position++;
        value *= _unary();
      } else if (token.isSymbol('/')) {
        _position++;
        final divisor = _unary();
        if (divisor == 0) throw const _CalcException(CalcError.divisionByZero);
        value /= divisor;
      } else if (token.startsValue) {
        // "2(3)", "2pi", "3sin(30)", "(1)(2)": multiplication that is not written.
        value *= _unary();
      } else {
        break;
      }
      _checkFinite(value);
    }
    return value;
  }

  double _unary() {
    final token = _peek;
    if (token != null && token.isSymbol('-')) {
      _position++;
      return -_unary();
    }
    if (token != null && token.isSymbol('+')) {
      _position++;
      return _unary();
    }
    return _power();
  }

  double _power() {
    final base = _postfix();
    final token = _peek;
    if (token != null && token.isSymbol('^')) {
      _position++;
      final exponent = _unary();
      return _pow(base, exponent);
    }
    return base;
  }

  double _postfix() {
    var value = _primary();
    while (_peek != null) {
      final token = _peek!;
      if (token.isSymbol('!')) {
        _position++;
        value = _factorial(value);
      } else if (token.isSymbol('%')) {
        _position++;
        value /= 100;
      } else {
        break;
      }
    }
    return value;
  }

  double _primary() {
    final token = _peek;
    if (token == null) throw const _CalcException(CalcError.syntax);
    switch (token.kind) {
      case _Kind.number || _Kind.constant:
        _position++;
        return token.number!;
      case _Kind.function:
        _position++;
        final open = _peek;
        if (open == null || !open.isSymbol('(')) throw const _CalcException(CalcError.syntax);
        final argument = _bracketed();
        return _apply(token.name, argument);
      case _Kind.symbol:
        if (token.isSymbol('(')) return _bracketed();
        throw const _CalcException(CalcError.syntax);
    }
  }

  /// "(" expression ")", counting how deeply brackets nest.
  double _bracketed() {
    _position++; // the "("
    if (++_depth > ScientificCalculator.maxDepth) throw const _CalcException(CalcError.tooDeep);
    final value = _expression();
    final close = _peek;
    if (close == null || !close.isSymbol(')')) throw const _CalcException(CalcError.syntax);
    _position++;
    _depth--;
    return value;
  }

  double _toRadians(double angle) => _mode == AngleMode.degrees ? angle * math.pi / 180 : angle;

  double _fromRadians(double angle) => _mode == AngleMode.degrees ? angle * 180 / math.pi : angle;

  double _apply(String name, double x) {
    switch (name) {
      case 'sin':
        return math.sin(_toRadians(x));
      case 'cos':
        return math.cos(_toRadians(x));
      case 'tan':
        final radians = _toRadians(x);
        // Where cos is zero the tangent does not exist (90°, 270°, π/2, ...).
        if (math.cos(radians).abs() < 1e-12) throw const _CalcException(CalcError.domain);
        return math.tan(radians);
      case 'asin':
        if (x < -1 || x > 1) throw const _CalcException(CalcError.domain);
        return _fromRadians(math.asin(x));
      case 'acos':
        if (x < -1 || x > 1) throw const _CalcException(CalcError.domain);
        return _fromRadians(math.acos(x));
      case 'atan':
        return _fromRadians(math.atan(x));
      case 'sqrt':
        if (x < 0) throw const _CalcException(CalcError.domain);
        return math.sqrt(x);
      case 'ln':
        if (x <= 0) throw const _CalcException(CalcError.domain);
        return math.log(x);
      case 'log':
        if (x <= 0) throw const _CalcException(CalcError.domain);
        return math.log(x) / math.ln10;
      case 'abs':
        return x.abs();
      case 'exp':
        return _checkFinite(math.exp(x));
    }
    throw const _CalcException(CalcError.syntax);
  }

  double _pow(double base, double exponent) {
    if (base == 0 && exponent < 0) throw const _CalcException(CalcError.divisionByZero);
    if (base < 0 && exponent != exponent.roundToDouble()) throw const _CalcException(CalcError.domain);
    return _checkFinite(math.pow(base, exponent).toDouble());
  }

  double _factorial(double x) {
    if (x < 0 || x != x.roundToDouble()) throw const _CalcException(CalcError.domain);
    if (x > 170) throw const _CalcException(CalcError.overflow);
    var result = 1.0;
    for (var factor = 2; factor <= x; factor++) {
      result *= factor;
    }
    return result;
  }

  double _checkFinite(double value) {
    if (value.isNaN) throw const _CalcException(CalcError.domain);
    if (value.isInfinite) throw const _CalcException(CalcError.overflow);
    return value;
  }
}
