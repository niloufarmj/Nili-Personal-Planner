import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tokens.dart';

/// Centered empty-state view with custom code-drawn blob atmosphere, icon, explainer, and sample hint.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.message,
    super.key,
    this.hint,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Code-drawn blob atmosphere behind the icon
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(160, 160),
                  painter: BlobPainter(isDark: isDark),
                ),
                Icon(
                  icon,
                  size: 56,
                  color: isDark
                      ? DesignTokens.accentDark
                      : DesignTokens.accentLight,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.fraunces(
                fontSize: DesignTokens.fontSection,
                fontWeight: FontWeight.w600,
                color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? DesignTokens.inkSoftDark
                      : DesignTokens.inkSoftLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: action,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusInput,
                    ),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BlobPainter extends CustomPainter {
  BlobPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final opacity = isDark ? 0.15 : 0.20;

    final paint1 = Paint()
      ..color = DesignTokens.resolvePastelFill(
        color: DesignTokens.rose,
        isDark: isDark,
      ).withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    final paint2 = Paint()
      ..color = DesignTokens.resolvePastelFill(
        color: DesignTokens.lavender,
        isDark: isDark,
      ).withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    final paint3 = Paint()
      ..color = DesignTokens.resolvePastelFill(
        color: DesignTokens.butter,
        isDark: isDark,
      ).withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(center + const Offset(-24, -12), 44, paint1);
    canvas.drawCircle(center + const Offset(24, -18), 38, paint2);
    canvas.drawCircle(center + const Offset(6, 22), 48, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
