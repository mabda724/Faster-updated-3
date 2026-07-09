import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// Faster App - Unified Theme (Deep Indigo)
/// Professional dark indigo design with blue accents.
class AppTheme {
  // ──────────────── Brand Colors (Deep Indigo) ────────────────
  static const Color primaryColor = Color(0xFF2D2175); // Deep Indigo (اللون الأساسي)
  static const Color secondaryColor = Color(0xFF2F80ED); // Blue (الأزرق)
  static const Color accentColor = Color(0xFF2F80ED); // Blue accent

  // ──────────────── Light Mode Colors ────────────────
  static const Color backgroundColor =
      Color(0xFFFFFFFF); // White (الخلفية)
  static const Color surfaceColor = Color(0xFFF6F7FB); // Light Gray (الخلفية الثانوية)
  static const Color textPrimary = Color(0xFF1E1E2F); // Dark Text (النص)
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400

  // ──────────────── Dark Mode Colors ────────────────
  static const Color darkBackgroundColor = Color(0xFF22115B); // Very Dark Purple (اللون الداكن)
  static const Color darkSurfaceColor = Color(0xFF2D2175); // Deep Indigo surface
  static const Color darkCardColor = Color(0xFF2D2175); // Deep Indigo card
  static const Color darkTextPrimary = Color(0xFFF1F5F9); // Slate 100
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkBorder = Color(0xFF3A2D8A); // Lighter indigo border

  // ──────────────── Semantic Colors ────────────────
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFFFC107); // Yellow (الأصفر)
  static const Color infoColor = Color(0xFF2D2175); // Primary
  static const Color tertiaryColor =
      Color(0xFFFFC107); // Yellow for ratings (الأصفر)

  // ──────────────── UI Element Colors (for backward compatibility) ────────────────
  static const Color dividerColor = Color(0xFFE5E7EB); // Light mode divider
  static const Color borderColor = Color(0xFFE5E7EB); // Light mode border
  static const Color surfaceColor70 = Color(0xB3FFFFFF); // 70% white (0xB3 ≈ 179/255)

  // ──────────────── Brand-Specific Colors ────────────────
  static const Color whatsappColor = Color(0xFF25D366);
  static const Color visaColor = Color(0xFF1A1F71);

  // ──────────────── Glass / Frost ────────────────
  static Color glassWhite = Colors.white.withValues(alpha: 0.7);
  static Color glassBorder = Colors.white.withValues(alpha: 0.5);
  static Color glassShadow = Colors.black.withValues(alpha: 0.06);

  // ──────────────── Gradients (Deep Indigo) ────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF22115B),
      Color(0xFF2D2175)
    ], // Dark Purple to Deep Indigo
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [
      Color(0xFF2F80ED),
      Color(0xFF60A5FA)
    ], // Blue to Light Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF6F7FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ──────────────── Adaptive Colors (context-aware) ────────────────
  static Color adaptiveBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackgroundColor
          : backgroundColor;

  static Color adaptiveSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceColor
          : surfaceColor;

  static Color adaptiveCard(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCardColor
          : Colors.white;

  static Color adaptiveTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : textPrimary;

  static Color adaptiveTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : textSecondary;

  static Color adaptiveBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorder
          : Colors.grey.shade100;

  static Color adaptiveIconColor(BuildContext context, Color lightColor) =>
      Theme.of(context).brightness == Brightness.dark
          ? lightColor.withValues(alpha: 0.9)
          : lightColor;

  // ──────────────── Light Theme Data ────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,

      // Typography (Design System §3.2 — complete type scale)
      textTheme: TextTheme(
        displayLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textDisplayLarge,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textDisplayMedium,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textTitleLarge,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textTitleMedium,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.cairo(
          fontSize: DesignTokens.textTitleSmall,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textBodyLarge,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textBodyMedium,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: DesignTokens.textBodySmall,
          color: textTertiary,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textLabelLarge,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        labelMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textLabelMedium,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
        labelSmall: GoogleFonts.cairo(
          fontSize: DesignTokens.textLabelSmall,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
      ),

      // Buttons (using DesignTokens)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: DesignTokens.elevation0,
          padding: DesignTokens.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.brLg,
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: DesignTokens.textBodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: DesignTokens.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.brLg,
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: DesignTokens.textBodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Inputs (using DesignTokens)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
        contentPadding: DesignTokens.inputPadding,
        border: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: BorderSide(color: textTertiary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: BorderSide(color: textTertiary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        hintStyle: GoogleFonts.cairo(
          color: textTertiary,
          fontSize: DesignTokens.textBodyMedium,
        ),
      ),

      // Card Theme (Glassmorphism — using DesignTokens)
      cardTheme: CardThemeData(
        elevation: DesignTokens.elevation0,
        color: Colors.white.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.brXl,
          side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return primaryColor.withValues(alpha: 0.3);
          return Colors.grey.shade300;
        }),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade100,
        thickness: 1,
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Tab bar
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textTertiary,
        indicatorColor: primaryColor,
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
      ),
    );
  }

  // ──────────────── Dark Theme Data ────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: darkSurfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,

      // Typography (Design System §3.2 — complete type scale)
      textTheme: TextTheme(
        displayLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textDisplayLarge,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textDisplayMedium,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textTitleLarge,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textTitleMedium,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        titleSmall: GoogleFonts.cairo(
          fontSize: DesignTokens.textTitleSmall,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textBodyLarge,
          color: darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textBodyMedium,
          color: darkTextSecondary,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: DesignTokens.textBodySmall,
          color: darkTextSecondary,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: DesignTokens.textLabelLarge,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
        labelMedium: GoogleFonts.cairo(
          fontSize: DesignTokens.textLabelMedium,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
        ),
        labelSmall: GoogleFonts.cairo(
          fontSize: DesignTokens.textLabelSmall,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
        ),
      ),

      // Buttons (using DesignTokens)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: DesignTokens.elevation0,
          padding: DesignTokens.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.brLg,
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: DesignTokens.textBodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side:
              BorderSide(color: accentColor.withValues(alpha: 0.5), width: 1.5),
          padding: DesignTokens.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.brLg,
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: DesignTokens.textBodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Inputs (using DesignTokens)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceColor,
        contentPadding: DesignTokens.inputPadding,
        border: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        hintStyle: GoogleFonts.cairo(
          color: darkTextSecondary,
          fontSize: DesignTokens.textBodyMedium,
        ),
      ),

      // Card Theme (using DesignTokens)
      cardTheme: CardThemeData(
        elevation: DesignTokens.elevation0,
        color: darkSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.brXl,
          side: BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentColor;
          return Colors.grey.shade600;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return accentColor.withValues(alpha: 0.3);
          return Colors.grey.shade700;
        }),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        textColor: darkTextPrimary,
        iconColor: darkTextSecondary,
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurfaceColor,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceColor,
        titleTextStyle: GoogleFonts.cairo(
            fontSize: 18, fontWeight: FontWeight.bold, color: darkTextPrimary),
      ),

      // SnackBar (using DesignTokens)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
      ),
    );
  }
}

/// Backward-compatible alias so existing code using `AppColors.xxx` still works.
/// New code should use `AppTheme.xxx` directly.
typedef AppColors = AppTheme;
