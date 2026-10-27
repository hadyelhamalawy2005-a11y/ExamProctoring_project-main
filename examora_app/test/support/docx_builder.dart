import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const String _wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const String _mNs = 'http://schemas.openxmlformats.org/officeDocument/2006/math';
const String _mcNs = 'http://schemas.openxmlformats.org/markup-compatibility/2006';

String _escape(String text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// A paragraph made of one run.
String para(String text) => '<w:p><w:r><w:t xml:space="preserve">${_escape(text)}</w:t></w:r></w:p>';

/// A paragraph whose text Word has split across several runs (as it does after editing or spell-checking).
String splitPara(List<String> pieces) =>
    '<w:p>${[for (final piece in pieces) '<w:r><w:t xml:space="preserve">${_escape(piece)}</w:t></w:r>'].join()}</w:p>';

/// A paragraph with a tracked insertion and a tracked deletion in it.
String trackedPara({required String kept, String? inserted, String? deleted}) =>
    '<w:p><w:r><w:t xml:space="preserve">${_escape(kept)}</w:t></w:r>'
    '${inserted == null ? '' : '<w:ins w:id="1" w:author="a"><w:r><w:t xml:space="preserve">${_escape(inserted)}</w:t></w:r></w:ins>'}'
    '${deleted == null ? '' : '<w:del w:id="2" w:author="a"><w:r><w:delText xml:space="preserve">${_escape(deleted)}</w:delText></w:r></w:del>'}'
    '</w:p>';

/// A paragraph with a line break in the middle (a soft return).
String breakPara(String first, String second) =>
    '<w:p><w:r><w:t>${_escape(first)}</w:t><w:br/><w:t>${_escape(second)}</w:t></w:r></w:p>';

/// A paragraph with a tab in the middle.
String tabPara(String first, String second) =>
    '<w:p><w:r><w:t>${_escape(first)}</w:t><w:tab/><w:t>${_escape(second)}</w:t></w:r></w:p>';

/// A paragraph containing a picture.
String imagePara() => '<w:p><w:r><w:drawing><wp:inline xmlns:wp="x"/></w:drawing></w:r></w:p>';

/// A table with one cell.
String tablePart(String cellText) => '<w:tbl><w:tr><w:tc>${para(cellText)}</w:tc></w:tr></w:tbl>';

/// A paragraph holding an equation between two pieces of text.
String equationPara(String before, String after) =>
    '<w:p><w:r><w:t xml:space="preserve">${_escape(before)}</w:t></w:r><m:oMath><m:r><m:t>x</m:t></m:r></m:oMath>'
    '<w:r><w:t xml:space="preserve">${_escape(after)}</w:t></w:r></w:p>';

/// A paragraph with hidden text.
String hiddenPara(String visible, String hidden) =>
    '<w:p><w:r><w:t xml:space="preserve">${_escape(visible)}</w:t></w:r>'
    '<w:r><w:rPr><w:vanish/></w:rPr><w:t>${_escape(hidden)}</w:t></w:r></w:p>';

/// A complete .docx (a zip with the parts Word needs) whose body is [bodyXml], or plain paragraphs in [paragraphs].
Uint8List buildDocx({
  List<String> paragraphs = const [],
  String bodyXml = '',
  bool contentTypes = true,
  bool documentPart = true,
  String? rawDocumentXml,
  Map<String, List<int>> extraParts = const {},
}) {
  final body = bodyXml.isEmpty ? paragraphs.map((p) => p.startsWith('<w:') ? p : para(p)).join() : bodyXml;
  final document =
      rawDocumentXml ??
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:document xmlns:w="$_wNs" xmlns:m="$_mNs" xmlns:mc="$_mcNs"><w:body>$body</w:body></w:document>';
  final archive = Archive();
  if (contentTypes) {
    final types = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    );
    archive.addFile(ArchiveFile('[Content_Types].xml', types.length, types));
  }
  if (documentPart) {
    final bytes = utf8.encode(document);
    archive.addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  }
  extraParts.forEach((name, bytes) => archive.addFile(ArchiveFile(name, bytes.length, bytes)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
