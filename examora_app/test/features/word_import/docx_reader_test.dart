import 'dart:typed_data';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/features/word_import/data/docx_reader.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/docx_builder.dart';
import '../../support/exam_fixtures.dart';

ExtractedDocument read(Uint8List bytes, {String name = 'questions.docx'}) =>
    ok(DocxReader.read(fileName: name, bytes: bytes));

DocumentRejection rejection(Uint8List bytes, {String name = 'questions.docx'}) {
  final failure = err(DocxReader.read(fileName: name, bytes: bytes));
  expect(failure, isA<DocumentRejectedFailure>());
  return (failure as DocumentRejectedFailure).reason;
}

void main() {
  group('reading a genuine .docx', () {
    test('returns every non-empty paragraph as a numbered line', () {
      final document = read(buildDocx(paragraphs: ['First', '', '  ', 'Second', 'Third']));
      expect(document.lines.map((l) => (l.number, l.text)), [(1, 'First'), (2, 'Second'), (3, 'Third')]);
      expect(document.skipped, isEmpty);
    });

    test('rejoins text that Word split across several runs', () {
      final document = read(
        buildDocx(
          paragraphs: [
            splitPara(['Qu', 'estion ', '1 [M', 'CQ]']),
          ],
        ),
      );
      expect(document.lines.single.text, 'Question 1 [MCQ]');
    });

    test('ignores text inside a tracked deletion but keeps a tracked insertion', () {
      final document = read(
        buildDocx(
          paragraphs: [trackedPara(kept: 'Correct Answer: ', inserted: 'B', deleted: 'A')],
        ),
      );
      expect(document.lines.single.text, 'Correct Answer: B');
    });

    test('splits a soft line break into two lines and keeps a tab', () {
      final document = read(buildDocx(paragraphs: [breakPara('A) one', 'B) two'), tabPara('left', 'right')]));
      expect(document.lines.map((l) => l.text), ['A) one', 'B) two', 'left\tright']);
    });

    test('removes invisible direction marks and turns non-breaking spaces into spaces', () {
      final document = read(buildDocx(paragraphs: ['\u200FCorrect Answer: \u202BB\u202C']));
      expect(document.lines.single.text, 'Correct Answer: B');
    });

    test('does not import hidden text', () {
      final document = read(buildDocx(paragraphs: [hiddenPara('Visible', ' secret')]));
      expect(document.lines.single.text, 'Visible');
    });

    test('reads Arabic text', () {
      final document = read(buildDocx(paragraphs: ['س12: ما هو؟', 'أ) الأول']));
      expect(document.lines.map((l) => l.text), ['س12: ما هو؟', 'أ) الأول']);
    });
  });

  group('content that cannot be imported is reported, not dropped', () {
    test('a table is skipped with the words that were in it, and where it was', () {
      final document = read(buildDocx(bodyXml: '${para('Before')}${tablePart('Cell text')}${para('After')}'));
      expect(document.lines.map((l) => l.text), ['Before', 'After']);
      expect(document.skipped.single.kind, SkippedKind.table);
      expect(document.skipped.single.afterLine, 1);
      expect(document.skipped.single.preview, 'Cell text');
    });

    test('a picture is skipped', () {
      final document = read(buildDocx(bodyXml: '${para('Before')}${imagePara()}${para('After')}'));
      expect(document.skipped.single.kind, SkippedKind.image);
      expect(document.skipped.single.afterLine, 1);
    });

    test('an equation is skipped and the words around it stay as separate lines', () {
      final document = read(buildDocx(bodyXml: equationPara('Solve ', ' for x')));
      expect(document.skipped.single.kind, SkippedKind.equation);
      expect(document.lines.map((l) => l.text), ['Solve', 'for x']);
    });

    test('a document with only a picture is not "empty": there is something to report', () {
      final document = read(buildDocx(bodyXml: imagePara()));
      expect(document.lines, isEmpty);
      expect(document.skipped, hasLength(1));
    });

    test('a long table preview is shortened', () {
      final document = read(buildDocx(bodyXml: tablePart('x' * 200)));
      expect(document.skipped.single.preview.length, lessThan(70));
    });
  });

  group('files that are not genuine .docx files are rejected with a reason', () {
    test('an older .doc by its name', () {
      expect(rejection(Uint8List.fromList([1, 2, 3]), name: 'exam.doc'), DocumentRejection.oldDoc);
      expect(rejection(Uint8List.fromList([1, 2, 3]), name: 'EXAM.DOC'), DocumentRejection.oldDoc);
    });

    test('an older .doc renamed to .docx is recognised by its content', () {
      final ole = Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0, 0, 0, 0]);
      expect(rejection(ole), DocumentRejection.oldDoc);
    });

    test('a PDF renamed to .docx', () {
      final pdf = Uint8List.fromList('%PDF-1.7\n%âãÏÓ\n1 0 obj'.codeUnits);
      expect(rejection(pdf), DocumentRejection.pdf);
    });

    test('text that is not a zip', () {
      expect(rejection(Uint8List.fromList('hello world, I am not a zip'.codeUnits)), DocumentRejection.notAZip);
    });

    test('another extension is refused', () {
      expect(rejection(buildDocx(paragraphs: ['x']), name: 'questions.pdf'), DocumentRejection.notDocx);
      expect(rejection(buildDocx(paragraphs: ['x']), name: 'questions'), DocumentRejection.notDocx);
    });

    test('a zip that is not a Word document (no document part, or no content types)', () {
      expect(
        rejection(
          buildDocx(
            documentPart: false,
            extraParts: {
              'xl/workbook.xml': [60, 120, 62],
            },
          ),
        ),
        DocumentRejection.notWord,
      );
      expect(rejection(buildDocx(paragraphs: ['x'], contentTypes: false)), DocumentRejection.notWord);
    });

    test('a zip with a damaged document part', () {
      expect(rejection(buildDocx(rawDocumentXml: '<w:document><w:body><w:p>')), DocumentRejection.unreadable);
    });

    test('a truncated zip', () {
      final good = buildDocx(paragraphs: ['Question 1 [MCQ]']);
      expect(rejection(Uint8List.sublistView(good, 0, good.length ~/ 2)), DocumentRejection.unreadable);
    });

    test('a document type declaration (a way to pull in outside content) is refused', () {
      final xml =
          '<?xml version="1.0"?><!DOCTYPE d [<!ENTITY e SYSTEM "file:///etc/passwd">]>'
          '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>&e;</w:t></w:r></w:p></w:body></w:document>';
      expect(rejection(buildDocx(rawDocumentXml: xml)), DocumentRejection.unreadable);
    });

    test('an empty file and a file with no text', () {
      expect(rejection(Uint8List(0)), DocumentRejection.empty);
      expect(rejection(buildDocx(paragraphs: ['', '   '])), DocumentRejection.empty);
    });

    test('over 10 MB is refused before anything is parsed', () {
      final big = Uint8List(DocxReader.maxFileBytes + 1);
      expect(rejection(big), DocumentRejection.tooLarge);
      // The limit is inclusive: exactly 10 MB of nonsense gets past the size check and fails on content instead.
      expect(rejection(Uint8List(DocxReader.maxFileBytes)), isNot(DocumentRejection.tooLarge));
    });
  });
}
