import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/features/word_import/data/docx_reader.dart';
import 'package:examora_app/features/word_import/data/word_file_source.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the template ships inside the app.
const String templateAssetPath = 'assets/templates/examora_question_template.docx';

/// Shows the rules and the template text from the help button.
Future<void> showTemplateHelp(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _TemplateHelpDialog());

class _TemplateHelpDialog extends ConsumerStatefulWidget {
  const _TemplateHelpDialog();

  @override
  ConsumerState<_TemplateHelpDialog> createState() => _TemplateHelpDialogState();
}

class _TemplateHelpDialogState extends ConsumerState<_TemplateHelpDialog> {
  late final Future<Uint8List> _bytes = _load();
  String? _notice;

  Future<Uint8List> _load() async {
    final data = await rootBundle.load(templateAssetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// The template's own text, read with the same reader the import uses.
  List<SourceLine> _lines(Uint8List bytes) {
    final result = DocxReader.read(fileName: 'template.docx', bytes: bytes);
    return switch (result) {
      Ok<ExtractedDocument>(:final value) => value.lines,
      Err<ExtractedDocument>() => const [],
    };
  }

  Future<void> _copy(List<SourceLine> lines) async {
    await Clipboard.setData(ClipboardData(text: lines.map((line) => line.text).join('\n')));
    if (!mounted) return;
    setState(() => _notice = context.strings.importTemplateCopied);
  }

  Future<void> _save(Uint8List bytes) async {
    final strings = context.strings;
    var saved = false;
    try {
      saved = await ref.read(wordFileSourceProvider).save(fileName: 'examora_question_template.docx', bytes: bytes);
    } on Object {
      saved = false;
    }
    if (!mounted) return;
    setState(() => _notice = saved ? strings.importTemplateSaved : strings.importTemplateSaveFailed);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.importTemplateTitle),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return snapshot.hasError
                  ? Text(strings.failureStorage)
                  : const Center(child: CircularProgressIndicator());
            }
            final lines = _lines(bytes);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.importTemplateRules, style: AppTypography.body),
                  const SizedBox(height: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: SelectableText(
                        lines.map((line) => line.text).join('\n'),
                        key: const Key('template-text'),
                        textDirection: TextDirection.ltr,
                        style: AppTypography.caption.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_notice!, style: AppTypography.caption),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: strings.importTemplateCopy,
                    icon: Icons.copy_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => unawaited(_copy(lines)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: strings.importTemplateSave,
                    icon: Icons.download_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => unawaited(_save(bytes)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(strings.close))],
    );
  }
}
