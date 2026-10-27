import 'package:examora_app/features/exam_session/domain/scientific_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

double value(String expression, {AngleMode mode = AngleMode.degrees}) {
  final result = ScientificCalculator.evaluate(expression, mode: mode);
  expect(
    result,
    isA<CalcValue>(),
    reason: '"$expression" should have a value but gave ${result is CalcFailure ? result.error : result}',
  );
  return (result as CalcValue).value;
}

CalcError error(String expression, {AngleMode mode = AngleMode.degrees}) {
  final result = ScientificCalculator.evaluate(expression, mode: mode);
  expect(
    result,
    isA<CalcFailure>(),
    reason: '"$expression" should fail but gave ${result is CalcValue ? result.value : result}',
  );
  return (result as CalcFailure).error;
}

void main() {
  group('arithmetic and precedence', () {
    test('the four operations', () {
      expect(value('2+3'), 5);
      expect(value('10-4'), 6);
      expect(value('6*7'), 42);
      expect(value('9/4'), 2.25);
    });

    test('multiplication and division bind tighter than addition and subtraction', () {
      expect(value('2+3*4'), 14);
      expect(value('2*3+4'), 10);
      expect(value('10-6/2'), 7);
      expect(value('10/2*5'), 25, reason: 'left to right');
      expect(value('10-4-3'), 3, reason: 'left to right');
    });

    test('brackets override precedence, and can nest', () {
      expect(value('(2+3)*4'), 20);
      expect(value('2*(3+4)*(5-1)'), 56);
      expect(value('((1+2)*(3+4))'), 21);
    });

    test('powers are right-associative and bind tighter than a unary minus', () {
      expect(value('2^3'), 8);
      expect(value('2^3^2'), 512, reason: '2^(3^2), not (2^3)^2');
      expect(value('-2^2'), -4, reason: '-(2^2)');
      expect(value('(-2)^2'), 4);
      expect(value('2^-1'), 0.5);
      expect(value('2*3^2'), 18);
    });

    test('unary plus and minus', () {
      expect(value('-5+3'), -2);
      expect(value('--5'), 5);
      expect(value('+5'), 5);
      expect(value('3*-2'), -6);
    });

    test('decimals', () {
      expect(value('0.1+0.2'), 0.3, reason: 'floating-point dust is tidied away');
      expect(value('.5*4'), 2);
      expect(value('1.5+1.5'), 3);
    });

    test('percent and factorial', () {
      expect(value('50%'), 0.5);
      expect(value('200*10%'), 20);
      expect(value('5!'), 120);
      expect(value('0!'), 1);
      expect(value('3!+2'), 8);
      expect(value('(2+1)!'), 6);
    });

    test('constants and unwritten multiplication', () {
      expect(value('pi'), closeTo(3.14159265359, 1e-9));
      expect(value('π'), closeTo(3.14159265359, 1e-9));
      expect(value('e'), closeTo(2.71828182846, 1e-9));
      expect(value('2pi'), closeTo(6.28318530718, 1e-9));
      expect(value('2(3+4)'), 14);
      expect(value('(1+1)(2+2)'), 8);
      expect(value('3sin(90)'), 3);
    });

    test('the symbols ×, ÷, − and Arabic-Indic digits are understood', () {
      expect(value('6×7'), 42);
      expect(value('8÷2'), 4);
      expect(value('9−4'), 5);
      expect(value('٢+٣'), 5);
      expect(value('٣٫٥*٢'), 7);
    });

    test('spaces are ignored', () {
      expect(value('  2  +   3 * 4 '), 14);
    });
  });

  group('trigonometry in degrees and in radians', () {
    test('degrees is the default', () {
      expect(value('sin(30)'), closeTo(0.5, 1e-12));
      expect(value('cos(60)'), closeTo(0.5, 1e-12));
      expect(value('tan(45)'), closeTo(1, 1e-12));
      expect(value('sin(90)'), 1);
      expect(value('cos(180)'), -1);
    });

    test('exact zeros: sin(180°) and cos(90°) are 0, not 1.2e-16', () {
      expect(value('sin(180)'), 0);
      expect(value('cos(90)'), 0);
      expect(value('sin(360)'), 0);
    });

    test('radians', () {
      expect(value('sin(pi/2)', mode: AngleMode.radians), 1);
      expect(value('cos(pi)', mode: AngleMode.radians), -1);
      expect(value('sin(pi)', mode: AngleMode.radians), 0);
      expect(value('tan(pi/4)', mode: AngleMode.radians), closeTo(1, 1e-12));
      expect(
        value('sin(30)', mode: AngleMode.radians),
        closeTo(-0.988031624093, 1e-9),
        reason: '30 radians, not degrees',
      );
    });

    test('the same number means different things in the two modes', () {
      expect(value('sin(30)'), isNot(value('sin(30)', mode: AngleMode.radians)));
    });

    test('inverse functions answer in the current unit', () {
      expect(value('asin(0.5)'), closeTo(30, 1e-9));
      expect(value('acos(0.5)'), closeTo(60, 1e-9));
      expect(value('atan(1)'), closeTo(45, 1e-9));
      expect(value('asin(1)', mode: AngleMode.radians), closeTo(1.5707963268, 1e-9));
      expect(value('atan(1)', mode: AngleMode.radians), closeTo(0.7853981634, 1e-9));
    });
  });

  group('other functions', () {
    test('roots, logs, absolute value and exponent', () {
      expect(value('sqrt(16)'), 4);
      expect(value('√(9)'), 3);
      expect(value('sqrt(2)*sqrt(2)'), 2);
      expect(value('ln(e)'), 1);
      expect(value('log(1000)'), closeTo(3, 1e-12));
      expect(value('log(100)'), 2);
      expect(value('abs(-7.5)'), 7.5);
      expect(value('exp(0)'), 1);
      expect(value('exp(1)'), closeTo(2.71828182846, 1e-9));
    });

    test('functions combine and nest', () {
      expect(value('sqrt(abs(-16))'), 4);
      expect(value('sin(asin(0.5))'), closeTo(0.5, 1e-9), reason: 'degrees both ways');
      expect(value('2*sqrt(9)+1'), 7);
    });
  });

  group('division by zero is an error, never Infinity', () {
    test('plain, repeated and zero over zero', () {
      expect(error('1/0'), CalcError.divisionByZero);
      expect(error('0/0'), CalcError.divisionByZero);
      expect(error('5/(3-3)'), CalcError.divisionByZero);
      expect(error('1/0/2'), CalcError.divisionByZero);
      expect(error('2+10/0'), CalcError.divisionByZero);
    });

    test('zero to a negative power', () {
      expect(error('0^-1'), CalcError.divisionByZero);
    });
  });

  group('domain errors', () {
    test('square root of a negative, logs of zero and negatives', () {
      expect(error('sqrt(-1)'), CalcError.domain);
      expect(error('ln(0)'), CalcError.domain);
      expect(error('ln(-5)'), CalcError.domain);
      expect(error('log(0)'), CalcError.domain);
      expect(error('log(-1)'), CalcError.domain);
    });

    test('inverse trigonometry outside [-1, 1]', () {
      expect(error('asin(2)'), CalcError.domain);
      expect(error('acos(-1.5)'), CalcError.domain);
    });

    test('tangent where it does not exist', () {
      expect(error('tan(90)'), CalcError.domain);
      expect(error('tan(270)'), CalcError.domain);
      expect(error('tan(pi/2)', mode: AngleMode.radians), CalcError.domain);
    });

    test('factorial of a negative or a fraction, a negative number to a fractional power', () {
      expect(error('(-1)!'), CalcError.domain);
      expect(error('2.5!'), CalcError.domain);
      expect(error('(-8)^0.5'), CalcError.domain);
    });
  });

  group('overflow', () {
    test('answers too large to represent are errors, not Infinity', () {
      expect(error('171!'), CalcError.overflow);
      expect(error('10^400'), CalcError.overflow);
      expect(error('exp(1000)'), CalcError.overflow);
      expect(error('9^9^9'), CalcError.overflow);
    });
  });

  group('syntax errors', () {
    test('incomplete or misplaced pieces', () {
      for (final bad in [
        '2+',
        '*3',
        '2**3',
        '(2+3',
        '2+3)',
        '()',
        '2+()',
        '1..2',
        '.',
        '2 3',
        '+',
        'sin',
        'sin 30',
        'sin()',
        '!5',
        '^2',
        '(',
      ]) {
        expect(error(bad), CalcError.syntax, reason: bad);
      }
    });

    test('empty and blank input', () {
      expect(error(''), CalcError.empty);
      expect(error('   '), CalcError.empty);
    });
  });

  group('NOTHING resembling code can be evaluated', () {
    test('words that are not functions or constants are rejected, never looked up', () {
      for (final attempt in [
        'alert(1)',
        'eval("1+1")',
        'print(5)',
        'import os',
        '__import__("os")',
        'System.exit(0)',
        'Process.run("calc")',
        'while(true)',
        'x=5',
        'x',
        'ans',
        'sin(x)',
        'foo(2)',
        'Math.sin(1)',
        'exec(1)',
      ]) {
        expect(error(attempt), CalcError.syntax, reason: attempt);
      }
    });

    test('symbols used for code are rejected', () {
      for (final attempt in [
        '1;2',
        '1,2',
        '[1]',
        '{1}',
        r'$1',
        '1&&1',
        '1||1',
        '1=1',
        '"a"',
        "'a'",
        '`1`',
        '1\\2',
        'a b',
        '2<3',
        '1#2',
        '@',
        '1?2:3',
      ]) {
        expect(error(attempt), CalcError.syntax, reason: attempt);
      }
    });

    test('control characters, emoji and unrelated scripts are rejected', () {
      for (final attempt in ['1\u0000+1', '1\n+1\u0007', '🙂', '١+٢Q', '日本語']) {
        expect(ScientificCalculator.evaluate(attempt), isNot(isA<CalcValue>()), reason: attempt);
      }
    });

    test('a function name needs brackets: it is never read as a value or a variable', () {
      expect(error('sin30'), CalcError.syntax);
      expect(error('sqrt4'), CalcError.syntax);
    });

    test('the only words that work are the listed functions and the constants pi and e', () {
      expect(ScientificCalculator.functions, {
        'sin',
        'cos',
        'tan',
        'asin',
        'acos',
        'atan',
        'sqrt',
        'ln',
        'log',
        'abs',
        'exp',
      });
      expect(value('PI'), closeTo(3.14159265359, 1e-9), reason: 'case does not matter for the allowed words');
      expect(error('pie'), CalcError.syntax);
      expect(error('exponent(1)'), CalcError.syntax);
    });
  });

  group('limits', () {
    test('an expression longer than the limit is refused', () {
      expect(error('${'1+' * 150}1'), CalcError.tooLong);
      expect(value('${'1+' * 50}1'), 51);
    });

    test('brackets nested too deeply are refused, not left to blow the stack', () {
      expect(error('${'(' * 41}1${')' * 41}'), CalcError.tooDeep);
      expect(value('${'(' * 40}1${')' * 40}'), 1);
      expect(error('${'sin(' * 100}1${')' * 100}'), isIn([CalcError.tooDeep, CalcError.tooLong]));
    });

    test('a huge number of digits is a number, an overflow or too long, never a hang', () {
      expect(value('9' * 199), greaterThan(1e198));
      expect(error('9' * 201), CalcError.tooLong);
    });
  });

  group('display', () {
    test('whole numbers have no decimal point, others at most 12 significant digits', () {
      expect(ScientificCalculator.format(5), '5');
      expect(ScientificCalculator.format(-12), '-12');
      expect(ScientificCalculator.format(2.5), '2.5');
      expect(ScientificCalculator.format(1 / 3), '0.333333333333');
      expect(ScientificCalculator.format(0.1 + 0.2), '0.3');
      expect(ScientificCalculator.format(1e20), '1e20');
      expect(ScientificCalculator.format(1.5e-7), '1.5e-7');
    });
  });
}
