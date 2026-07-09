import 'package:flutter/material.dart';

/// Faster App — Design Tokens
/// Service marketplace: professional, trustworthy, modern, warm
/// Base unit: 4dp spacing rhythm (Material Design 3)
class DesignTokens {
  // ──────────────────────────────────────────────
  // Spacing (4dp base unit) - Reduced for better mobile UX
  // ──────────────────────────────────────────────
  static const double space0 = 0;
  static const double space1 = 2;
  static const double space2 = 4;
  static const double space3 = 6;
  static const double space4 = 8;
  static const double space5 = 10;
  static const double space6 = 12;
  static const double space7 = 14;
  static const double space8 = 16;
  static const double space9 = 18;
  static const double space10 = 20;
  static const double space12 = 24;
  static const double space14 = 28;
  static const double space16 = 32;

  // Legacy compatibility aliases (used by many screens) - Reduced
  static const double space20 = 16;
  static const double space24 = 20;
  static const double space32 = 24;
  static const double space40 = 28;
  static const double space48 = 32;
  static const double space64 = 40;

  // Edge insets helpers
  static const EdgeInsets padding4 = EdgeInsets.all(space1);
  static const EdgeInsets padding8 = EdgeInsets.all(space2);
  static const EdgeInsets padding12 = EdgeInsets.all(space3);
  static const EdgeInsets padding16 = EdgeInsets.all(space4);
  static const EdgeInsets padding20 = EdgeInsets.all(space5);
  static const EdgeInsets padding24 = EdgeInsets.all(space6);

  static const EdgeInsets hPadding8 = EdgeInsets.symmetric(horizontal: space2);
  static const EdgeInsets hPadding12 = EdgeInsets.symmetric(horizontal: space3);
  static const EdgeInsets hPadding16 = EdgeInsets.symmetric(horizontal: space4);
  static const EdgeInsets hPadding20 = EdgeInsets.symmetric(horizontal: space5);
  static const EdgeInsets hPadding24 = EdgeInsets.symmetric(horizontal: space6);
  static const EdgeInsets vPadding8 = EdgeInsets.symmetric(vertical: space2);
  static const EdgeInsets vPadding12 = EdgeInsets.symmetric(vertical: space3);
  static const EdgeInsets vPadding16 = EdgeInsets.symmetric(vertical: space4);
  static const EdgeInsets vPadding20 = EdgeInsets.symmetric(vertical: space5);
  static const EdgeInsets vPadding24 = EdgeInsets.symmetric(vertical: space6);

  static const EdgeInsets pagePadding = EdgeInsets.all(space5);
  static const EdgeInsets pagePaddingH = EdgeInsets.symmetric(horizontal: space24);
  static const EdgeInsets pagePaddingV = EdgeInsets.symmetric(vertical: space24);

  // ──────────────────────────────────────────────
  // Border Radius
  // ──────────────────────────────────────────────
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;
  static const double radiusFull = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(radiusXs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius br2xl = BorderRadius.all(Radius.circular(radius2xl));
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(radiusFull));

  // ──────────────────────────────────────────────
  // Elevations & Shadows (Material Design 3 scale)
  // ──────────────────────────────────────────────
  static const double elevation0 = 0;
  static const double elevation1 = 1;
  static const double elevation2 = 2;
  static const double elevation3 = 3;
  static const double elevation4 = 4;
  static const double elevation5 = 5;

  /// Level 1 — Cards, list items
  static List<BoxShadow> shadow1(Color shadowColor) => [
        BoxShadow(
          blurRadius: 4,
          offset: const Offset(0, 1),
          color: shadowColor.withValues(alpha: 0.05),
        ),
      ];

  /// Level 2 — Elevated cards, dropdowns
  static List<BoxShadow> shadow2(Color shadowColor) => [
        BoxShadow(
          blurRadius: 8,
          offset: const Offset(0, 2),
          color: shadowColor.withValues(alpha: 0.08),
        ),
      ];

  /// Level 3 — FAB, bottom sheets, dialogs
  static List<BoxShadow> shadow3(Color shadowColor) => [
        BoxShadow(
          blurRadius: 12,
          offset: const Offset(0, 4),
          color: shadowColor.withValues(alpha: 0.12),
        ),
      ];

  /// Level 4 — Modals, elevated dialogs
  static List<BoxShadow> shadow4(Color shadowColor) => [
        BoxShadow(
          blurRadius: 20,
          offset: const Offset(0, 4),
          color: shadowColor.withValues(alpha: 0.15),
        ),
      ];

  /// Level 5 — Full-screen overlays, toasts
  static List<BoxShadow> shadow5(Color shadowColor) => [
        BoxShadow(
          blurRadius: 24,
          offset: const Offset(0, 8),
          color: shadowColor.withValues(alpha: 0.18),
        ),
      ];

  // ──────────────────────────────────────────────
  // Animation Durations & Curves
  // ──────────────────────────────────────────────
  static const Duration durationInstant = Duration(milliseconds: 50);
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Duration durationModal = Duration(milliseconds: 300);
  static const Duration durationPage = Duration(milliseconds: 350);

  // Curves
  static const Curve curveFastOut = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve curveEmphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve curveEaseInOut = Cubic(0.22, 1, 0.36, 1);
  // Legacy alias
  static const Curve curveEaseOut = Curves.easeOut;

  // ──────────────────────────────────────────────
  // Icon Sizing
  // ──────────────────────────────────────────────
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 40;
  static const double iconAvatar = 48;
  static const double iconDoctorAvatar = 72;

  // ──────────────────────────────────────────────
  // Component Sizing - Reduced for mobile
  // ──────────────────────────────────────────────
  static const double buttonHeight = 44;
  static const double buttonHeightSmall = 36;
  static const double inputHeight = 44;
  static const double bottomNavHeight = 56;
  static const double appBarHeight = 52;
  static const double touchTargetMin = 40;

  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: space4, vertical: space3);
  static const EdgeInsets buttonPaddingSmall =
      EdgeInsets.symmetric(horizontal: space3, vertical: space2);
  static const EdgeInsets buttonPaddingIcon =
      EdgeInsets.all(space2);

  static const EdgeInsets inputPadding =
      EdgeInsets.symmetric(horizontal: space3, vertical: space3);

  static const EdgeInsets cardPadding = EdgeInsets.all(space3);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(space2);

  // ──────────────────────────────────────────────
  // Opacity
  // ──────────────────────────────────────────────
  static const double opacityDisabled = 0.38;
  static const double opacityMuted = 0.60;
  static const double opacityMedium = 0.50;
  static const double opacityOverlay = 0.40;

  // ──────────────────────────────────────────────
  // Typography Sizing (Material 3 type scale) - Reduced for mobile
  // ──────────────────────────────────────────────
  static const double textDisplayLarge = 24;
  static const double textDisplayMedium = 20;
  static const double textTitleLarge = 18;
  static const double textTitleMedium = 16;
  static const double textTitleSmall = 14;
  static const double textBodyLarge = 14;
  static const double textBodyMedium = 12;
  static const double textBodySmall = 11;
  static const double textLabelLarge = 12;
  static const double textLabelMedium = 11;
  static const double textLabelSmall = 10;

  // ──────────────────────────────────────────────
  // Layout Tokens
  // ──────────────────────────────────────────────
  static const double screenPadding = 20;
  static const double sectionGap = 24;
  static const double cardGap = 16;
  static const double gridGap = 12;

  // ──────────────────────────────────────────────
  // OTP Tokens
  // ──────────────────────────────────────────────
  static const double otpBoxSize = 52;
  static const double otpRadius = 14;
  static const double otpGap = 10;
  static const double otpActiveBorder = 2;

  // ──────────────────────────────────────────────
  // Search Bar Tokens
  // ──────────────────────────────────────────────
  static const double searchBarHeight = 48;
  static const double searchBarRadius = 24;
}
