import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the user chose. The bytes are not read until [read] is called, so the size can be checked first.
final class PickedWordFile {
  /// Creates the record.
  const PickedWordFile({required this.name, required this.size, required this.read});

  /// The file name, with its extension.
  final String name;

  /// The size in bytes, or null when the platform did not say (then the bytes are checked once they are read).
  final int? size;

  /// Reads the whole file.
  final Future<Uint8List> Function() read;
}

/// Where Word files come from and where the template goes. A seam so tests can supply files without a system dialog.
abstract interface class WordFileSource {
  /// Lets the user choose a file. Completes with null when they cancel.
  Future<PickedWordFile?> pick();

  /// Offers [bytes] to the user as a file called [fileName]. Completes with true when it was saved.
  Future<bool> save({required String fileName, required Uint8List bytes});
}

/// The real file chooser (the platform's own dialog).
final class SystemWordFileSource implements WordFileSource {
  /// Creates the source.
  const SystemWordFileSource();

  @override
  Future<PickedWordFile?> pick() async {
    // Any file type is allowed on purpose: a .doc or a PDF is then refused with an explanation instead of being
    // hidden from the chooser.
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    return PickedWordFile(name: file.name, size: await file.length(), read: file.readAsBytes);
  }

  @override
  Future<bool> save({required String fileName, required Uint8List bytes}) async {
    final target = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    return target != null;
  }
}

/// The file source the app uses. Tests override it.
final wordFileSourceProvider = Provider<WordFileSource>((ref) => const SystemWordFileSource());
