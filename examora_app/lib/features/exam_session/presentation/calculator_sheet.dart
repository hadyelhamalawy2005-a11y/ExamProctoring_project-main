import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/features/exam_session/domain/scientific_calculator.dart';
import 'package:flutter/material.dart';

/// Opens the scientific calculator over the exam.
Future<void> showCalculator(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const CalculatorSheet(),
);

/// A scientific calculator. Everything typed is evaluated by [ScientificCalculator], which has its own small grammar: there
/// is nothing in it that could run code.
class CalculatorSheet extends StatefulWidget {
  /// Creates the sheet.
  const CalculatorSheet({super.key});

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expression = '';
  AngleMode _mode = AngleMode.degrees;
  CalcResult? _result;

  void _add(String text) => setState(() {
    _expression += text;
    _result = null;
  });

  void _clear() => setState(() {
    _expression = '';
    _result = null;
  });

  void _backspace() => setState(() {
    if (_expression.isNotEmpty) _expression = _expression.substring(0, _expression.length - 1);
    _result = null;
  });

  void _equals() => setState(() => _result = ScientificCalculator.evaluate(_expression, mode: _mode));

  Widget _key(String label, {String? insert, VoidCallback? onTap, bool strong = false}) {
    return SizedBox(
      width: 64,
      height: AppDimensions.minTouchTarget,
      child: strong
          ? FilledButton(onPressed: onTap ?? () => _add(insert ?? label), child: Text(label))
          : OutlinedButton(
              onPressed: onTap ?? () => _add(insert ?? label),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(label),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final result = _result;
    final String shown;
    final bool isError;
    switch (result) {
      case null:
        shown = '';
        isError = false;
      case CalcValue(:final value):
        shown = ScientificCalculator.format(value);
        isError = false;
      case CalcFailure(:final error):
        shown = strings.calcError(error);
        isError = true;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(strings.calcTitle, style: AppTypography.heading)),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Semantics(
                    label: strings.calcExpression,
                    child: Text(
                      _expression.isEmpty ? ' ' : _expression,
                      key: const Key('calc-expression'),
                      textDirection: TextDirection.ltr,
                      style: AppTypography.heading,
                    ),
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      shown.isEmpty ? ' ' : shown,
                      key: const Key('calc-result'),
                      textDirection: isError ? null : TextDirection.ltr,
                      style: AppTypography.title.copyWith(color: isError ? AppColors.danger : AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<AngleMode>(
            segments: [
              ButtonSegment(value: AngleMode.degrees, label: Text(strings.calcDegrees)),
              ButtonSegment(value: AngleMode.radians, label: Text(strings.calcRadians)),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() {
              _mode = selection.first;
              _result = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final fn in const ['sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'ln', 'log', 'sqrt', 'abs', 'exp'])
                  _key(fn, insert: '$fn('),
                _key('π', insert: 'pi'),
                _key('e'),
                _key('('),
                _key(')'),
                _key('^'),
                _key('!'),
                _key('%'),
                for (final digit in ['7', '8', '9', '÷', '4', '5', '6', '×', '1', '2', '3', '-', '0', '.', '+'])
                  _key(digit),
                _key('⌫', onTap: _backspace),
                _key('C', onTap: _clear),
                _key('=', onTap: _equals, strong: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
