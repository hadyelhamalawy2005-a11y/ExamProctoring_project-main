import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:xml/xml.dart';

/// Reads the text of a genuine .docx on the device: opens the zip, parses `word/document.xml`, rejoins text that Word split
/// across runs, and ignores text inside tracked deletions.
///
/// Only that one part is read, as plain XML. Macros, embedded objects, links and pictures are never opened. A file is
/// refused before parsing if it is too big, is a PDF or an old `.doc` in disguise, or is not a Word document at all.
abstract final class DocxReader {
  /// The largest file accepted, checked before anything is parsed.
  static const int maxFileBytes = 10 * 1024 * 1024;

  /// The most entries a .docx may hold.
  static const int maxEntries = 2000;

  /// The largest `word/document.xml` after decompression. A 10 MB .docx of text is far below this; a zip bomb is not.
  static const int maxDocumentXmlBytes = 20 * 1024 * 1024;

  static const String _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const String _m = 'http://schemas.openxmlformats.org/officeDocument/2006/math';
  static const String _mc = 'http://schemas.openxmlformats.org/markup-compatibility/2006';

  /// Reads [bytes], the content of the file called [fileName].
  static Result<ExtractedDocument> read({required String fileName, required Uint8List bytes}) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.doc')) return const Err(DocumentRejectedFailure(DocumentRejection.oldDoc));
    if (!lowerName.endsWith('.docx')) return const Err(DocumentRejectedFailure(DocumentRejection.notDocx));
    if (bytes.length > maxFileBytes) return const Err(DocumentRejectedFailure(DocumentRejection.tooLarge));
    if (bytes.isEmpty) return const Err(DocumentRejectedFailure(DocumentRejection.empty));

    // What the file really is, whatever it is called.
    if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46])) {
      return const Err(DocumentRejectedFailure(DocumentRejection.pdf));
    }
    if (_startsWith(bytes, const [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])) {
      return const Err(DocumentRejectedFailure(DocumentRejection.oldDoc));
    }
    if (!_startsWith(bytes, const [0x50, 0x4B])) {
      return const Err(DocumentRejectedFailure(DocumentRejection.notAZip));
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      return const Err(DocumentRejectedFailure(DocumentRejection.unreadable));
    }
    // A zip with nothing in it is a damaged or truncated one: a real .docx always has its parts.
    if (archive.files.isEmpty) return const Err(DocumentRejectedFailure(DocumentRejection.unreadable));
    if (archive.files.length > maxEntries) return const Err(DocumentRejectedFailure(DocumentRejection.tooComplex));

    ArchiveFile? document;
    var hasContentTypes = false;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') document = file;
      if (file.name == '[Content_Types].xml') hasContentTypes = true;
    }
    if (document == null || !hasContentTypes) return const Err(DocumentRejectedFailure(DocumentRejection.notWord));
    if (document.size > maxDocumentXmlBytes) return const Err(DocumentRejectedFailure(DocumentRejection.tooComplex));

    final String xmlText;
    try {
      final content = document.content;
      if (content.length > maxDocumentXmlBytes) return const Err(DocumentRejectedFailure(DocumentRejection.tooComplex));
      xmlText = utf8.decode(content);
    } on Object {
      return const Err(DocumentRejectedFailure(DocumentRejection.unreadable));
    }
    // No document type or entity declarations: nothing in this part may pull in anything from elsewhere.
    if (xmlText.contains('<!DOCTYPE') || xmlText.contains('<!ENTITY')) {
      return const Err(DocumentRejectedFailure(DocumentRejection.unreadable));
    }

    final XmlDocument xml;
    try {
      xml = XmlDocument.parse(xmlText);
    } on XmlException {
      return const Err(DocumentRejectedFailure(DocumentRejection.unreadable));
    }

    final extractor = _Extractor();
    final body = xml.rootElement.childElements.where((element) => _is(element, _w, 'body'));
    for (final element in body) {
      extractor.readBlockContainer(element);
    }
    if (extractor.lines.isEmpty && extractor.skipped.isEmpty) {
      return const Err(DocumentRejectedFailure(DocumentRejection.empty));
    }
    return Ok(ExtractedDocument(lines: extractor.lines, skipped: extractor.skipped));
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }

  static bool _is(XmlElement element, String namespace, String local) =>
      element.name.local == local && element.name.namespaceUri == namespace;
}

/// Walks the document in reading order, collecting lines and the content it cannot turn into text.
final class _Extractor {
  final List<SourceLine> lines = [];
  final List<SkippedContent> skipped = [];
  final StringBuffer _current = StringBuffer();

  static const String _w = DocxReader._w;
  static const String _m = DocxReader._m;
  static const String _mc = DocxReader._mc;

  bool _isW(XmlElement element, String local) => DocxReader._is(element, _w, local);

  /// The children of the body (or of a content control): paragraphs, tables and nested content controls.
  void readBlockContainer(XmlElement container) {
    for (final child in container.childElements) {
      if (_isW(child, 'p')) {
        _readParagraph(child);
      } else if (_isW(child, 'tbl')) {
        skipped.add(SkippedContent(kind: SkippedKind.table, afterLine: lines.length, preview: _preview(child)));
      } else if (_isW(child, 'sdt')) {
        for (final content in child.childElements.where((e) => _isW(e, 'sdtContent'))) {
          readBlockContainer(content);
        }
      } else if (child.name.local == 'AlternateContent' && child.name.namespaceUri == _mc) {
        for (final choice in child.childElements.where((e) => e.name.local == 'Choice')) {
          readBlockContainer(choice);
        }
      }
    }
  }

  void _readParagraph(XmlElement paragraph) {
    _readInline(paragraph);
    _flush();
  }

  /// The inline content of a paragraph or of a wrapper inside it (insertion, hyperlink, field, content control).
  void _readInline(XmlElement parent) {
    for (final child in parent.childElements) {
      final namespace = child.name.namespaceUri;
      final local = child.name.local;
      if (namespace == _m && (local == 'oMath' || local == 'oMathPara')) {
        _flushKeepingLine();
        skipped.add(
          SkippedContent(kind: SkippedKind.equation, afterLine: lines.length, preview: _current.toString().trim()),
        );
        continue;
      }
      if (namespace == _mc) {
        if (local == 'AlternateContent') {
          for (final choice in child.childElements.where((e) => e.name.local == 'Choice')) {
            _readInline(choice);
          }
        }
        continue;
      }
      if (namespace != _w) continue;
      switch (local) {
        case 'r':
          _readRun(child);
        case 'del' || 'moveFrom':
          // A tracked deletion: the text is gone from the document, so it is gone from the import too.
          break;
        case 'ins' ||
            'moveTo' ||
            'hyperlink' ||
            'smartTag' ||
            'fldSimple' ||
            'sdtContent' ||
            'sdt' ||
            'customXml' ||
            'bdo' ||
            'dir':
          _readInline(child);
        default:
          break;
      }
    }
  }

  void _readRun(XmlElement run) {
    // Hidden text is not visible to the author, so it is not imported.
    final properties = run.childElements.where((e) => _isW(e, 'rPr'));
    for (final property in properties) {
      if (property.childElements.any((e) => _isW(e, 'vanish'))) return;
    }
    for (final child in run.childElements) {
      if (child.name.namespaceUri != _w) continue;
      switch (child.name.local) {
        case 't':
          _current.write(child.innerText);
        case 'tab':
          _current.write('\t');
        case 'noBreakHyphen':
          _current.write('-');
        case 'br' || 'cr':
          _flush();
        case 'drawing' || 'pict' || 'object':
          skipped.add(SkippedContent(kind: SkippedKind.image, afterLine: lines.length));
        default:
          break;
      }
    }
  }

  /// Adds the text collected so far as a line, if there is any.
  void _flush() {
    final text = _clean(_current.toString());
    _current.clear();
    if (text.isNotEmpty) lines.add(SourceLine(lines.length + 1, text));
  }

  /// Like [_flush], used before an equation so the words before it become their own line.
  void _flushKeepingLine() => _flush();

  /// Removes invisible direction marks, turns non-breaking spaces into spaces and trims.
  static String _clean(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune == 0x00A0) {
        buffer.write(' ');
      } else if (_isDirectionMark(rune)) {
        continue;
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trim();
  }

  static bool _isDirectionMark(int rune) =>
      rune == 0x200E ||
      rune == 0x200F ||
      rune == 0x061C ||
      (rune >= 0x202A && rune <= 0x202E) ||
      (rune >= 0x2066 && rune <= 0x2069) ||
      rune == 0xFEFF;

  /// The first words inside [element], for telling the person where a table was.
  String _preview(XmlElement element) {
    final text = element.descendantElements.where((e) => _isW(e, 't')).map((e) => e.innerText).join(' ').trim();
    return text.length > 60 ? '${text.substring(0, 60)}…' : text;
  }
}
