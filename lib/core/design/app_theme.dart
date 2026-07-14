import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
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
        labelStyle: GoogleFonts.nunitoSans(
          fontSize: DesignTokens.fontCaption,
          fontWeight: FontWeight.w600,
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
        selectedLabelStyle: GoogleFonts.nunitoSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.nunitoSans(
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
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: DesignTokens.fontTitle,
          fontWeight: FontWeight.w600,
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
      textTheme: _textTheme(isDark),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    final baseColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final secondaryColor = isDark
        ? DesignTokens.inkSoftDark
        : DesignTokens.inkSoftLight;

    return TextTheme(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: DesignTokens.fontDisplay,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.fraunces(
        fontSize: DesignTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: DesignTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: DesignTokens.fontSection,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: DesignTokens.fontSection,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.fraunces(
        fontSize: DesignTokens.fontSection,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontBody,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontCaption,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ),
      bodyLarge: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontBody,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontBody - 1, // 14
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodySmall: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontCaption,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontCaption,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelMedium: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontCaption - 1, // 12
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelSmall: GoogleFonts.nunitoSans(
        fontSize: DesignTokens.fontOverline, // 11
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: secondaryColor,
      ),
    );
  }
}
