import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Switches between Arabic and English immediately. Each language is named in its own language.
class LanguageSwitcher extends ConsumerWidget {
  /// Creates the switcher.
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider).languageCode;
    return Semantics(
      container: true,
      label: context.strings.languageLabel,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'ar', label: Text('العربية')),
          ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {current},
        onSelectionChanged: (selection) => switchLanguage(ref, selection.first),
      ),
    );
  }
}
