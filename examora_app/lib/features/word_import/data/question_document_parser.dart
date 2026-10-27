import 'package:examora_app/core/utilities/number_parsing.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';

/// Turns the lines of a Word document into questions.
///
/// The documented template is
///
/// ```
/// Question 1 [MCQ]
/// Which layer routes packets?
/// A. Physical
/// B. Network
/// Correct Answer: B
/// Marks: 1
/// Difficulty: Easy        (optional)
/// Topic: Networking       (optional)
/// ```
///
/// with `[Multiple]` for several correct options and `[Short]` for a typed answer (`Model Answer:` instead of options).
/// Ordinary writing styles are read too: `Q1:`, `1.`, `1)`, `س12:`, options as `A)`, `(A)`, `أ)`, `Points:`, section
/// headings. Whatever the document does not say is left out and reported: a missing mark is never defaulted, an answer is
/// never inferred, text that fits nowhere is listed, and a question whose kind had to be guessed is flagged.
abstract final class QuestionDocumentParser {
  static const String _digit = r'[0-9٠-٩۰-۹]';
  static const String _number = '$_digit+(?:[.,٫]$_digit+)?';
  // A single option letter: Latin, or an Arabic letter in the traditional order (alef, beh, jeem, dal, heh, waw, zain,
  // hah, teh, yeh).
  static const String _letter = r'[A-Za-zاأبجدهوزحطي]';
  static const String _marksUnit = r'points?|pts?|marks?|درجات|درجة';

  static final RegExp _title = RegExp(
    r'^(?:(?:exam|test)\s+title|عنوان\s+(?:الامتحان|الاختبار))\s*[:：]\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _section = RegExp(
    r'^(?:(?:section|part|chapter|unit)\s*(?:' +
        _digit +
        r'+|[A-Za-z]|[IVXivx]+)|(?:القسم|الجزء|الباب|الفصل)\s+\S+)\s*(?:[:：.\-–—]\s*(.*))?$',
    caseSensitive: false,
  );
  static final RegExp _typeHeading = RegExp(
    r'^(?:multiple[\s-]*choice|mcq|essay|written|short(?:\s+answer)?)(?:\s+(?:questions?|items?|section|part))*\s*[:：]?\s*$',
    caseSensitive: false,
  );
  static final RegExp _questionStart = RegExp(
    r'^(?:question|quest|q|السؤال|سؤال|س)\s*(?:no\.?|number|#|رقم)?\s*[.:]?\s*(' +
        _digit +
        r'+)\s*(?:[\[(]\s*([^\])]*?)\s*[\])])?\s*(?:[:：.)\-–—]\s*)?(.*)$',
    caseSensitive: false,
  );
  static final RegExp _bareNumber = RegExp('^($_digit+)\\s*[.)\\-–—:]\\s+(\\S.*)\$');
  static final RegExp _typeLine = RegExp(
    r'^(?:question\s+type|type|نوع\s+السؤال|النوع)\s*[:：]\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _optionLine = RegExp(
    r'^(?:\((' + _letter + r')\)|(' + _letter + r')[.):：\-–—](?=\s|$))\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _nextInlineOption = RegExp(
    r'(?:\t|\s{2,})(?=[*✓✔☑]?\s*\(?' + _letter + r'\)\s)',
    caseSensitive: false,
  );
  static final RegExp _answerLine = RegExp(
    r'^(?:correct\s+(?:answer|option|choice)s?|right\s+(?:answer|option|choice)|answers?|ans|key|الإجابة\s+الصحيحة|الاجابة\s+الصحيحة|الإجابة|الاجابة|الجواب)\s*(?:[:：=]|\bis\b\s*[:：]?)\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _modelAnswerLine = RegExp(
    r'^(?:model\s+answer|sample\s+answer|expected\s+answer|الإجابة\s+النموذجية|الاجابة\s+النموذجية)\s*[:：]\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _marksLine = RegExp(
    r'^(?:marks?|points?|score|grade|degree|الدرجة|الدرجات|درجة|العلامة|العلامات)\s*[:：=]\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _marksValue = RegExp('^($_number)(?:\\s*(?:$_marksUnit))?\$', caseSensitive: false);
  static final RegExp _marksSuffix = RegExp(
    '\\s*[(\\[]\\s*($_number)\\s*(?:$_marksUnit)\\s*[)\\]]\\s*\$',
    caseSensitive: false,
  );
  static final RegExp _difficultyLine = RegExp(
    r'^(?:difficulty|level|الصعوبة|مستوى\s+الصعوبة)\s*[:：]\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _topicLine = RegExp(r'^(?:topic|subject|الموضوع)\s*[:：]\s*(.*)$', caseSensitive: false);
  static final RegExp _explanationLine = RegExp(
    r'^(?:explanation|rationale|الشرح|التفسير)\s*[:：]\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _leadingMark = RegExp(r'^[*✓✔☑]+\s*');
  static final RegExp _trailingMark = RegExp(
    r'(?:\s*[*✓✔☑]+|\s*[(\[]\s*(?:correct(?:\s+answer)?|right)\s*[)\]])\s*$',
    caseSensitive: false,
  );
  static final RegExp _labelList = RegExp(
    '^\\(?($_letter)\\)?(?:\\s*(?:[,;&/،]|\\s(?:and|و)\\s)\\s*\\(?($_letter)\\)?)*\\s*\$',
    caseSensitive: false,
  );
  static final RegExp _labelWithText = RegExp('^\\(?($_letter)\\)?[.):]\\s*.*\$', caseSensitive: false);

  static const Map<String, String> _arabicLetters = {
    'ا': 'A',
    'أ': 'A',
    'ب': 'B',
    'ج': 'C',
    'د': 'D',
    'ه': 'E',
    'و': 'F',
    'ز': 'G',
    'ح': 'H',
    'ط': 'I',
    'ي': 'J',
  };

  /// The marks, as a number, from the text after "Marks:", or null when it is not a number.
  static double? parseMarks(String text) {
    final match = _marksValue.firstMatch(text.trim());
    if (match == null) return null;
    return NumberParsing.parseDecimal(match.group(1)!);
  }

  /// Reads [document] into questions and the lines that belong to no question.
  static ImportPreview parse(ExtractedDocument document) {
    final state = _State();
    for (final line in document.lines) {
      _readLine(state, line);
    }
    state.finishQuestion(atEnd: true);
    return ImportPreview(
      questions: state.questions,
      unattached: state.unattached,
      ignored: state.ignored,
      skipped: document.skipped,
      documentTitle: state.title,
    );
  }

  static void _readLine(_State state, SourceLine line) {
    final text = line.text.replaceAll('\t', ' ').trim();
    if (text.isEmpty) return;

    final title = _title.firstMatch(text);
    if (title != null) {
      state.title ??= title.group(1)!.trim();
      state.ignored.add(line);
      return;
    }

    final section = _section.firstMatch(text);
    if (section != null || _typeHeading.hasMatch(text)) {
      // A heading ends the question before it and may set the default kind of the questions after it.
      state.finishQuestion();
      state.sectionKind = _headingKind(section == null ? text : (section.group(1) ?? ''));
      state.ignored.add(line);
      return;
    }

    final start = _questionStart.firstMatch(text);
    if (start != null) {
      final tag = start.group(2);
      state.startQuestion(
        number: NumberParsing.parseInt(start.group(1)!) ?? state.questions.length + 1,
        line: line,
        tag: tag,
        text: start.group(3) ?? '',
      );
      return;
    }

    final current = state.current;
    final bare = _bareNumber.firstMatch(text);
    if (bare != null) {
      final number = NumberParsing.parseInt(bare.group(1)!);
      // A bare number starts a question only where one can start: first in the document or after a heading, or when it
      // follows on from a previous question that is complete. Otherwise it is a numbered line inside something else.
      if (number != null && (current == null || (number == state.lastNumber + 1 && current.isComplete))) {
        state.startQuestion(number: number, line: line, tag: null, text: bare.group(2)!);
        return;
      }
    }

    if (current == null) {
      state.unattached.add(line);
      return;
    }
    current.sourceLines.add(line);

    if (_typeLine.firstMatch(text) case final match?) {
      final value = match.group(1)!.trim();
      final kind = _kindOf(value);
      if (kind == null) {
        current.issues.add(ImportIssue(ImportIssueCode.unknownTypeTag, detail: value, line: line.number));
      } else {
        current.declaredType = kind;
      }
      return;
    }
    if (_modelAnswerLine.firstMatch(text) case final match?) {
      current.modelLines.add(match.group(1)!.trim());
      current.last = _Target.model;
      return;
    }
    if (_answerLine.firstMatch(text) case final match?) {
      current.answers.add(_AnswerLine(match.group(1)!.trim(), line.number));
      current.last = _Target.none;
      return;
    }
    if (_marksLine.firstMatch(text) case final match?) {
      current.marksLines.add(match.group(1)!.trim());
      current.last = _Target.none;
      return;
    }
    if (_difficultyLine.firstMatch(text) case final match?) {
      current.difficulty = match.group(1)!.trim();
      current.last = _Target.none;
      return;
    }
    if (_topicLine.firstMatch(text) case final match?) {
      current.topic = match.group(1)!.trim();
      current.last = _Target.none;
      return;
    }
    if (_explanationLine.firstMatch(text) case final match?) {
      current.explanationLines.add(match.group(1)!.trim());
      current.last = _Target.explanation;
      return;
    }
    if (_optionLine.firstMatch(text.replaceFirst(_leadingMark, '')) != null) {
      _readOptions(current, line.text.trim(), line.number);
      return;
    }

    switch (current.last) {
      case _Target.text:
        if (!current.hasStructure) {
          current.textLines.add(text);
          return;
        }
      case _Target.model:
        current.modelLines.add(text);
        return;
      case _Target.explanation:
        current.explanationLines.add(text);
        return;
      case _Target.option || _Target.none:
        break;
    }
    // Text that fits nowhere in this question. It is listed, and the question is flagged if more of the document follows.
    state.unattached.add(line);
    current.pendingStray.add(ImportIssue(ImportIssueCode.strayText, detail: text, line: line.number));
  }

  /// One option line, possibly several options written side by side, possibly marked as correct.
  static void _readOptions(_Question question, String rawLine, int lineNumber) {
    for (final part in rawLine.split(_nextInlineOption)) {
      final trimmed = part.trim();
      final leadingMark = _leadingMark.hasMatch(trimmed);
      final match = _optionLine.firstMatch(trimmed.replaceFirst(_leadingMark, ''));
      if (match == null) {
        // Not an option after all: keep the words with the previous option.
        if (question.options.isNotEmpty) question.options.last.text += ' $trimmed';
        continue;
      }
      var optionText = match.group(3)!.trim();
      var marked = leadingMark;
      if (_trailingMark.hasMatch(optionText)) {
        marked = true;
        optionText = optionText.replaceFirst(_trailingMark, '').trim();
      }
      final label = _labelOf(match.group(1) ?? match.group(2)!);
      if (question.options.any((option) => option.label == label)) {
        question.issues.add(ImportIssue(ImportIssueCode.duplicateOptionLabel, detail: label, line: lineNumber));
      }
      question.options.add(_Option(label, optionText));
      if (marked) question.markedLabels.add(label);
    }
    question.last = _Target.option;
  }

  static String _labelOf(String letter) => _arabicLetters[letter] ?? letter.toUpperCase();

  /// The type a word names, or null when it names none the importer knows.
  static QuestionType? _kindOf(String word) {
    final value = word.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (RegExp(r'^(?:essay|short|short\s*(?:text|answer)|text|written|open|مقالي|مقالية|نصي)(?:\s+questions?)?$')
        .hasMatch(value)) {
      return QuestionType.shortText;
    }
    if (RegExp(r'^(?:multiple\s*(?:answers?|select)|multi|msq|checkbox|multiple)$').hasMatch(value)) {
      return QuestionType.multipleChoice;
    }
    if (RegExp(r'^(?:mcq|single|single\s*(?:choice|answer)|multiple[\s-]*choice|choice)(?:\s+questions?)?$')
        .hasMatch(value)) {
      return QuestionType.singleChoice;
    }
    if (value.contains('اختيار')) return QuestionType.singleChoice;
    return null;
  }

  /// The default kind a heading such as "Section 2: Essay Questions" gives the questions after it, or null.
  static QuestionType? _headingKind(String heading) {
    final value = heading.toLowerCase();
    if (value.contains('essay') || value.contains('written') || value.contains('short') || value.contains('مقال')) {
      return QuestionType.shortText;
    }
    if (value.contains('multiple choice') ||
        value.contains('multiple-choice') ||
        value.contains('mcq') ||
        value.contains('اختيار')) {
      return QuestionType.singleChoice;
    }
    return null;
  }

  static List<String>? _answerLabels(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_labelList.hasMatch(trimmed)) {
      return [
        for (final match in RegExp(_letter, caseSensitive: false).allMatches(_stripConjunctions(trimmed)))
          _labelOf(match.group(0)!),
      ];
    }
    final single = _labelWithText.firstMatch(trimmed);
    if (single != null) return [_labelOf(single.group(1)!)];
    return null;
  }

  /// Removes the words "and" / "و" between letters so only the letters remain.
  static String _stripConjunctions(String value) =>
      value.replaceAll(RegExp(r'\s(?:and|و)\s', caseSensitive: false), ',');
}

enum _Target { none, text, option, model, explanation }

final class _Option {
  _Option(this.label, this.text);

  final String label;
  String text;
}

final class _AnswerLine {
  _AnswerLine(this.value, this.line);

  final String value;
  final int line;
}

final class _Question {
  _Question({required this.number, required this.startLine, required this.sectionKind, this.declaredType});

  final int number;
  final int startLine;
  final QuestionType? sectionKind;
  QuestionType? declaredType;
  final List<SourceLine> sourceLines = [];
  final List<String> textLines = [];
  final List<_Option> options = [];
  final Set<String> markedLabels = {};
  final List<_AnswerLine> answers = [];
  final List<String> marksLines = [];
  final List<String> modelLines = [];
  final List<String> explanationLines = [];
  final List<ImportIssue> issues = [];
  final List<ImportIssue> pendingStray = [];
  String? difficulty;
  String? topic;
  double? suffixMarks;
  _Target last = _Target.text;

  /// True once options, an answer or marks have been seen, so plain text can no longer be part of the question text.
  bool get hasStructure => options.isNotEmpty || answers.isNotEmpty || marksLines.isNotEmpty;

  /// True once the question has said what its answer or its marks are: only then can a bare number start the next one.
  bool get isComplete => answers.isNotEmpty || marksLines.isNotEmpty;
}

final class _State {
  final List<ParsedQuestion> questions = [];
  final List<SourceLine> unattached = [];
  final List<SourceLine> ignored = [];
  final Set<int> numbers = {};
  String? title;
  QuestionType? sectionKind;
  _Question? current;
  int lastNumber = 0;

  void startQuestion({required int number, required SourceLine line, required String? tag, required String text}) {
    finishQuestion();
    lastNumber = number;
    final declared = tag == null ? null : QuestionDocumentParser._kindOf(tag);
    final question = _Question(
      number: number,
      startLine: line.number,
      sectionKind: sectionKind,
      declaredType: declared,
    );
    question.sourceLines.add(line);
    if (tag != null && tag.isNotEmpty && declared == null) {
      question.issues.add(ImportIssue(ImportIssueCode.unknownTypeTag, detail: tag, line: line.number));
    }
    if (!numbers.add(number)) {
      question.issues.add(ImportIssue(ImportIssueCode.duplicateQuestionNumber, detail: '$number', line: line.number));
    }
    var first = text.trim();
    final suffix = QuestionDocumentParser._marksSuffix.firstMatch(first);
    if (suffix != null) {
      question.suffixMarks = NumberParsing.parseDecimal(suffix.group(1)!);
      first = first.substring(0, suffix.start).trim();
    }
    if (first.isNotEmpty) question.textLines.add(first);
    current = question;
  }

  /// Ends the open question. [atEnd] is true at the end of the document, where trailing text is not a defect of the
  /// question before it (a closing remark is just listed).
  void finishQuestion({bool atEnd = false}) {
    final question = current;
    if (question == null) return;
    current = null;
    if (!atEnd) question.issues.addAll(question.pendingStray);
    questions.add(_build(question));
  }

  ParsedQuestion _build(_Question question) {
    final issues = [...question.issues];
    final options = [
      for (final option in question.options) ParsedOption(label: option.label, text: option.text.trim()),
    ];
    final optionLabels = {for (final option in options) option.label};

    // Answers: the answer lines plus any option marked in place. Unreadable or unknown letters are reported, never guessed.
    final correct = <String>{};
    final answerSets = <Set<String>>[];
    final hasOptions = options.isNotEmpty;
    var modelFromAnswer = false;
    final modelLines = [...question.modelLines];
    for (final answer in question.answers) {
      if (!hasOptions && (question.declaredType ?? question.sectionKind) == QuestionType.shortText) {
        if (modelLines.isEmpty) {
          modelLines.add(answer.value);
          modelFromAnswer = true;
        } else {
          issues.add(ImportIssue(ImportIssueCode.strayText, detail: answer.value, line: answer.line));
        }
        continue;
      }
      final labels = QuestionDocumentParser._answerLabels(answer.value);
      if (labels == null || labels.isEmpty) {
        if (!hasOptions && question.declaredType == null) {
          if (modelLines.isEmpty) {
            modelLines.add(answer.value);
            modelFromAnswer = true;
          }
          continue;
        }
        issues.add(ImportIssue(ImportIssueCode.unknownAnswerLabel, detail: answer.value, line: answer.line));
        continue;
      }
      final known = <String>{};
      for (final label in labels) {
        if (optionLabels.contains(label)) {
          known.add(label);
        } else {
          issues.add(ImportIssue(ImportIssueCode.unknownAnswerLabel, detail: label, line: answer.line));
        }
      }
      answerSets.add(known);
      correct.addAll(known);
    }
    if (answerSets.length > 1 &&
        answerSets.any((set) => set.length != answerSets.first.length || !set.containsAll(answerSets.first))) {
      issues.add(const ImportIssue(ImportIssueCode.conflictingAnswerLines));
    }
    if (question.markedLabels.isNotEmpty) {
      if (answerSets.isNotEmpty &&
          !(question.markedLabels.length == correct.length && question.markedLabels.containsAll(correct))) {
        issues.add(const ImportIssue(ImportIssueCode.conflictingAnswerLines));
      }
      correct.addAll(question.markedLabels);
    }
    if (modelFromAnswer) issues.add(const ImportIssue(ImportIssueCode.answerTreatedAsModel));

    // The type: written down, from a heading, or (flagged) guessed from the shape of the question.
    var type = question.declaredType ?? question.sectionKind;
    if (type == null) {
      type = hasOptions
          ? (correct.length > 1 ? QuestionType.multipleChoice : QuestionType.singleChoice)
          : QuestionType.shortText;
      issues.add(const ImportIssue(ImportIssueCode.typeInferred));
    }
    if (type == QuestionType.singleChoice && correct.length > 1) {
      issues.add(const ImportIssue(ImportIssueCode.severalAnswersForSingle));
    }

    // Marks: from the Marks line or a "(2 points)" suffix. Never defaulted.
    double? marks = question.suffixMarks;
    if (question.marksLines.isNotEmpty) {
      final value = question.marksLines.last;
      final parsed = QuestionDocumentParser.parseMarks(value);
      if (parsed == null) {
        issues.add(ImportIssue(ImportIssueCode.marksUnreadable, detail: value));
      } else {
        marks = parsed;
      }
    }
    if (marks == null && !issues.any((issue) => issue.code == ImportIssueCode.marksUnreadable)) {
      issues.add(const ImportIssue(ImportIssueCode.missingMarks));
    }

    String? joined(List<String> lines) {
      final text = lines.where((line) => line.isNotEmpty).join('\n').trim();
      return text.isEmpty ? null : text;
    }

    return ParsedQuestion(
      number: question.number,
      startLine: question.startLine,
      sourceLines: question.sourceLines,
      type: type,
      text: question.textLines.join('\n').trim(),
      options: options,
      correctLabels: correct,
      marks: marks,
      modelAnswer: joined(modelLines),
      explanation: joined(question.explanationLines),
      topic: question.topic == null || question.topic!.isEmpty ? null : question.topic,
      difficulty: question.difficulty == null || question.difficulty!.isEmpty ? null : question.difficulty,
      issues: issues,
    );
  }
}
