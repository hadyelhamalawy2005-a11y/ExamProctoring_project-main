import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contrastRatio', () {
    test('black on white is 21:1 and identical colours are 1:1', () {
      expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
      expect(contrastRatio(AppColors.brand, AppColors.brand), closeTo(1, 0.0001));
    });

    test('is symmetric', () {
      expect(
        contrastRatio(AppColors.text, AppColors.surface),
        closeTo(contrastRatio(AppColors.surface, AppColors.text), 0.0001),
      );
    });
  });

  // Every ratio the design claims. WCAG 2.x AA: 4.5:1 for normal text.
  group('WCAG AA (4.5:1) for every text and background pair the design uses', () {
    const aa = 4.5;
    final pairs = <String, (Color, Color)>{
      'body text on cards': (AppColors.text, AppColors.surface),
      'body text on the page': (AppColors.text, AppColors.background),
      'muted text on cards': (AppColors.textMuted, AppColors.surface),
      'muted text on the page': (AppColors.textMuted, AppColors.background),
      'white on the primary action colour': (AppColors.onPrimary, AppColors.primary),
      'white on the danger colour': (AppColors.onPrimary, AppColors.danger),
      'white on the navy app bar': (AppColors.onNavy, AppColors.navy),
      'primary text on cards (secondary buttons)': (AppColors.primary, AppColors.surface),
      'danger text on cards': (AppColors.danger, AppColors.surface),
      'danger text on its banner': (AppColors.danger, AppColors.dangerSurface),
      'success text on cards': (AppColors.success, AppColors.surface),
      'success text on its banner': (AppColors.success, AppColors.successSurface),
      'warning text on cards': (AppColors.warning, AppColors.surface),
      'warning text on its banner': (AppColors.warning, AppColors.warningSurface),
      'info text on cards': (AppColors.info, AppColors.surface),
      'info text on its banner': (AppColors.info, AppColors.infoSurface),
      'navy text on cards': (AppColors.navy, AppColors.surface),
    };

    pairs.forEach((name, pair) {
      test(name, () {
        expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(aa), reason: name);
      });
    });
  });

  test('the brand blue is for accents and focus only: white text on it would NOT pass AA, which is why buttons use primary', () {
    expect(contrastRatio(AppColors.onPrimary, AppColors.brand), lessThan(4.5));
    expect(contrastRatio(AppColors.onPrimary, AppColors.primary), greaterThanOrEqualTo(4.5));
  });

  test('the brand colours are the ones in the brief', () {
    expect(AppColors.brand, const Color(0xFF5F87E4));
    expect(AppColors.navy, const Color(0xFF262B3A));
  });

  test('touch targets are at least 48 and text scaling is capped at 1.6', () {
    expect(AppDimensions.minTouchTarget, greaterThanOrEqualTo(48));
    expect(AppDimensions.buttonHeight, greaterThanOrEqualTo(48));
    expect(AppDimensions.maxTextScale, 1.6);
  });
}
