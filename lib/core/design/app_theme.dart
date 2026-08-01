import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'font_options.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light([AppFontOption font = AppFontOption.classic]) =>
      _buildTheme(Brightness.light, font);
  static ThemeData dark([AppFontOption font = AppFontOption.classic]) =>
      _buildTheme(Brightness.dark, font);

  static ThemeData _buildTheme(Brightness brightness, AppFontOption font) {
    final isDark = brightness == Brightness.dark;

    // Configure Google Fonts to be offline-only (no network calls)
    GoogleFonts.config.allowRuntimeFetching = false;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
      brightness: brightness,
      primary: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
      onPrimary: Colors.white,
      secondary: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
      onSecondary: Colors.white,
      surface: isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight,
      onSurface: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
      outline: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark
          ? DesignTokens.paperDark
          : DesignTokens.paperLight,
      cardTheme: CardThemeData(
        color: isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
            width: 1,
          ),
          borderRadius: const BorderRadius.all(
            Radius.circular(DesignTokens.radiusCard),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        ),
        side: BorderSide(
          color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
          width: 1,
        ),
        backgroundColor: isDark
            ? DesignTokens.surfaceDark
            : DesignTokens.surfaceLight,
        labelStyle: GoogleFonts.getFont(
          font.bodyFamily,
          fontSize: DesignTokens.fontCaption,
          fontWeight: font.emphasisWeight,
          color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? DesignTokens.paperDark
            : DesignTokens.paperLight,
        selectedItemColor: isDark
            ? DesignTokens.accentDark
            : DesignTokens.accentLight,
        unselectedItemColor: isDark
            ? DesignTokens.inkSoftDark
            : DesignTokens.inkSoftLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.getFont(
          font.bodyFamily,
          fontSize: 11,
          fontWeight: font.emphasisWeight,
        ),
        unselectedLabelStyle: GoogleFonts.getFont(
          font.bodyFamily,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? DesignTokens.paperDark
            : DesignTokens.paperLight,
        foregroundColor: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.getFont(
          font.headlineFamily,
          fontSize: DesignTokens.fontTitle,
          fontWeight: font.emphasisWeight,
          color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? DesignTokens.surfaceDark
            : DesignTokens.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(
            color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(
            color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(
            color: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
            width: 2,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark
            ? DesignTokens.accentDark
            : DesignTokens.accentLight,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignTokens.radiusCard),
          ),
        ),
      ),
      textTheme: _textTheme(isDark, font),
    );
  }

  static TextTheme _textTheme(bool isDark, AppFontOption font) {
    final baseColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final secondaryColor = isDark
        ? DesignTokens.inkSoftDark
        : DesignTokens.inkSoftLight;
    final headline = font.headlineFamily;
    final body = font.bodyFamily;
    final emphasis = font.emphasisWeight;

    return TextTheme(
      displayLarge: GoogleFonts.getFont(
        headline,
        fontSize: 36,
        fontWeight: emphasis,
        color: baseColor,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.getFont(
        headline,
        fontSize: DesignTokens.fontDisplay,
        fontWeight: emphasis,
        color: baseColor,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.getFont(
        headline,
        fontSize: DesignTokens.fontTitle,
        fontWeight: emphasis,
        color: baseColor,
      ),
      headlineLarge: GoogleFonts.getFont(
        headline,
        fontSize: DesignTokens.fontTitle,
        fontWeight: emphasis,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.getFont(
        headline,
        fontSize: DesignTokens.fontSection,
        fontWeight: emphasis,
        color: baseColor,
      ),
      headlineSmall: GoogleFonts.getFont(
        headline,
        fontSize: DesignTokens.fontSection,
        fontWeight: emphasis,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.getFont(
        headline,
        fontSize: DesignTokens.fontSection,
        fontWeight: emphasis,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontBody,
        fontWeight: emphasis,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontCaption,
        fontWeight: emphasis,
        color: secondaryColor,
      ),
      bodyLarge: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontBody,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontBody - 1, // 14
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodySmall: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontCaption,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontCaption,
        fontWeight: emphasis,
        color: baseColor,
      ),
      labelMedium: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontCaption - 1, // 12
        fontWeight: emphasis,
        color: baseColor,
      ),
      labelSmall: GoogleFonts.getFont(
        body,
        fontSize: DesignTokens.fontOverline, // 11
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: secondaryColor,
      ),
    );
  }
}
