import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Every colour in the app. Widgets never use a literal colour.
///
/// Contrast claims below are asserted by `test/app/theme/design_tokens_test.dart`.
abstract final class AppColors {
  /// The brand blue (accents, selection, focus).
  static const Color brand = Color(0xFF5F87E4);

  /// The brand navy (app bars, headings on light backgrounds).
  static const Color navy = Color(0xFF262B3A);

  /// The action colour: a darker shade of the brand blue so white text on it passes WCAG AA (4.5:1).
  static const Color primary = Color(0xFF2457C5);

  /// Text and icons on [primary] and on [danger].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Text and icons on [navy].
  static const Color onNavy = Color(0xFFFFFFFF);

  /// Page background.
  static const Color background = Color(0xFFF5F6F8);

  /// Cards and sheets.
  static const Color surface = Color(0xFFFFFFFF);

  /// Body text (AA on [surface] and on [background]).
  static const Color text = Color(0xFF1F2933);

  /// Secondary text (AA on [surface] and on [background]).
  static const Color textMuted = Color(0xFF52606D);

  /// Hairlines and borders.
  static const Color border = Color(0xFFD9DEE5);

  /// Destructive actions and error text (AA on [surface] and on [dangerSurface]).
  static const Color danger = Color(0xFFB42318);

  /// Background of error banners.
  static const Color dangerSurface = Color(0xFFFDECEA);

  /// Success text (AA on [surface] and on [successSurface]).
  static const Color success = Color(0xFF1B6E40);

  /// Background of success banners.
  static const Color successSurface = Color(0xFFE7F5ED);

  /// Warning text (AA on [surface] and on [warningSurface]).
  static const Color warning = Color(0xFF7A4F00);

  /// Background of warning banners.
  static const Color warningSurface = Color(0xFFFFF6E0);

  /// Informational text (AA on [surface] and on [infoSurface]).
  static const Color info = Color(0xFF1D4F9F);

  /// Background of informational banners.
  static const Color infoSurface = Color(0xFFEAF1FD);
}

/// The WCAG 2.x contrast ratio between two opaque colours, from 1 (identical) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color color) {
  double channel(double value) => value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// Spacing scale, in logical pixels.
abstract final class AppSpacing {
  /// 4.
  static const double xs = 4;

  /// 8.
  static const double sm = 8;

  /// 12.
  static const double md = 12;

  /// 16.
  static const double lg = 16;

  /// 24.
  static const double xl = 24;

  /// 32.
  static const double xxl = 32;
}

/// Corner radii.
abstract final class AppRadii {
  /// Small controls.
  static const double sm = 6;

  /// Cards and fields.
  static const double md = 10;

  /// Sheets and dialogs.
  static const double lg = 16;

  /// Pills and badges.
  static const double pill = 999;
}

/// Icon sizes.
abstract final class AppIconSizes {
  /// Inline with text.
  static const double sm = 18;

  /// Default.
  static const double md = 24;

  /// Large status icons.
  static const double lg = 48;
}

/// Fixed dimensions.
abstract final class AppDimensions {
  /// The widest a content column grows on a tablet or desktop window.
  static const double maxContentWidth = 600;

  /// The smallest comfortable touch target.
  static const double minTouchTarget = 48;

  /// Height of buttons.
  static const double buttonHeight = 48;

  /// The highest text scale the app honours, so an exam's layout cannot break at the largest accessibility sizes.
  static const double maxTextScale = 1.6;
}

/// Animation and delay durations.
abstract final class AppDurations {
  /// Quick state changes.
  static const Duration short = Duration(milliseconds: 150);

  /// Page-level transitions.
  static const Duration medium = Duration(milliseconds: 300);
}

/// Text styles. Colours come from the theme, never from here.
abstract final class AppTypography {
  /// The font stack: platform default first, then fonts that cover Arabic.
  static const List<String> fontFamilyFallback = ['Segoe UI', 'Tahoma', 'Noto Naskh Arabic', 'Noto Sans Arabic'];

  /// Screen titles.
  static const TextStyle title = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);

  /// Section headings.
  static const TextStyle heading = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3);

  /// Body text.
  static const TextStyle body = TextStyle(fontSize: 15, height: 1.45);

  /// Secondary text.
  static const TextStyle caption = TextStyle(fontSize: 13, height: 1.4);

  /// Button labels.
  static const TextStyle button = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
}
