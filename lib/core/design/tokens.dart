import 'dart:ui';
import 'package:flutter/material.dart';

/// Central source of truth for the planner's design system tokens.
/// All colors, font properties, shapes, and shadows must originate here.
abstract final class DesignTokens {
  // ── Neutrals (Light Mode) ───────────────────────────────────────
  static const Color paperLight = Color(
    0xFFFBF7F4,
  ); // app background - warm off-white
  static const Color surfaceLight = Color(0xFFFFFFFF); // card background
  static const Color inkLight = Color(
    0xFF4A3F45,
  ); // primary text (warm plum-charcoal)
  static const Color inkSoftLight = Color(0xFF8A7B82); // secondary text
  static const Color lineLight = Color(0xFFEFE6E4); // hairline dividers/borders

  // ── Neutrals (Dark Mode) ────────────────────────────────────────
  static const Color paperDark = Color(
    0xFF2A2430,
  ); // app background - warm plum-black
  static const Color surfaceDark = Color(0xFF352E3C); // card background
  static const Color inkDark = Color(0xFFF2EAEE); // primary text
  static const Color inkSoftDark = Color(0xFFA599A0); // secondary text
  static const Color lineDark = Color(0xFF473F4F); // hairline dividers/borders

  // ── Accent (Only saturated color) ──────────────────────────────
  static const Color accentLight = Color(0xFFC76B82); // deep dusty rose
  static const Color accentDark = Color(
    0xFFD38B9B,
  ); // desaturated/dimmed accent

  // ── Pastel Family (Light Mode) ──────────────────────────────────
  static const Color rose = Color(0xFFE7A6B7);
  static const Color roseSoft = Color(0xFFF6DDE4);
  static const Color blush = Color(0xFFF3C6CF);
  static const Color blushSoft = Color(0xFFFBE9ED);
  static const Color lavender = Color(0xFFC2BBF0);
  static const Color lavenderSoft = Color(0xFFE9E6FA);
  static const Color sage = Color(0xFFBFD8C2);
  static const Color sageSoft = Color(0xFFE6F0E7);
  static const Color dustyBlue = Color(0xFFA8BFDD);
  static const Color dustyBlueSoft = Color(0xFFE3EBF6);
  static const Color butter = Color(0xFFF4E3B2);
  static const Color butterSoft = Color(0xFFFBF3DC);
  static const Color peach = Color(0xFFF6CBB7);
  static const Color peachSoft = Color(0xFFFCE9E0);

  // ── Semantic Semantic Palette ───────────────────────────────────
  static const Color success = Color(0xFF8FBF9F);
  static const Color warning = Color(0xFFE0B470);
  static const Color danger = Color(0xFFD98E9C);

  // ── Shape & Depth ──────────────────────────────────────────────
  static const double radiusCard = 20.0;
  static const double radiusInput = 14.0;
  static const double radiusSheet = 28.0;

  /// Soft ambient shadow for cards
  static List<BoxShadow> shadow(Color inkColor) => [
    BoxShadow(
      color: inkColor.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Helper functions for Dark Mode conversion ───────────────────
  /// Desaturate by 20% and dim by 15%
  static Color adjustColorForDark(Color color) {
    final hsl = HSLColor.fromColor(color);
    final double newSaturation = (hsl.saturation * 0.8).clamp(0.0, 1.0);
    final double newLightness = (hsl.lightness * 0.85).clamp(0.0, 1.0);
    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      newSaturation,
      newLightness,
    ).toColor();
  }

  /// Get the appropriate resolved colors for background/chip fills
  static Color resolvePastelFill({
    required Color color,
    required bool isDark,
    double? customOpacity,
  }) {
    if (isDark) {
      final adjusted = adjustColorForDark(color);
      return adjusted.withValues(alpha: customOpacity ?? 0.20);
    } else {
      return color;
    }
  }

  // ── Typography scales ───────────────────────────────────────────
  static const double fontDisplay = 32.0;
  static const double fontTitle = 24.0;
  static const double fontSection = 18.0;
  static const double fontBody = 15.0;
  static const double fontCaption = 13.0;
  static const double fontOverline = 11.0;
}

/// A custom decoration that creates a soft diagonal gradient wash
/// to represent day activity/location tags without visual clutter.
class DayWashDecoration extends Decoration {
  const DayWashDecoration({required this.tagColors, required this.isDark});

  final List<Color> tagColors;
  final bool isDark;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DayWashPainter(tagColors, isDark);
  }
}

class _DayWashPainter extends BoxPainter {
  _DayWashPainter(this.tagColors, this.isDark);

  final List<Color> tagColors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & (configuration.size ?? Size.zero);
    if (rect.isEmpty) return;

    final basePaper = isDark ? DesignTokens.paperDark : DesignTokens.paperLight;

    if (tagColors.isEmpty) {
      final paint = Paint()..color = basePaper;
      canvas.drawRect(rect, paint);
      return;
    }

    final double washOpacity = isDark ? 0.20 : 0.25;

    // Build the colors for the gradient
    final List<Color> gradientColors = [];
    if (tagColors.length == 1) {
      final resolved = DesignTokens.resolvePastelFill(
        color: tagColors.first,
        isDark: isDark,
        customOpacity: washOpacity,
      );
      gradientColors.add(resolved);
      gradientColors.add(basePaper);
    } else {
      for (final color in tagColors) {
        gradientColors.add(
          DesignTokens.resolvePastelFill(
            color: color,
            isDark: isDark,
            customOpacity: washOpacity,
          ),
        );
      }
    }

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientColors,
    );

    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);
  }
}
