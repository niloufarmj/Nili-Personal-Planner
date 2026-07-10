import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/design.dart';
import 'badge_service.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgesAsync = ref.watch(earnedBadgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements & Badges'),
      ),
      body: badgesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (badges) {
          final unlockedCount = badges.where((b) => b.isUnlocked).length;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Header Summary Card
              AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesignTokens.butter.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: DesignTokens.butter,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unlockedCount / ${badges.length} Unlocked',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: badges.isEmpty ? 0 : unlockedCount / badges.length,
                            backgroundColor: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                            color: DesignTokens.butter,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Badges Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  return _BadgeGridItem(badge: badge);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeGridItem extends StatelessWidget {
  const _BadgeGridItem({required this.badge});
  final BadgeInfo badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight;
    final cardBorder = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;

    return GestureDetector(
      onTap: () => _showBadgeDetails(context, badge),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(
            color: badge.isUnlocked
                ? badge.color.withValues(alpha: 0.5)
                : cardBorder,
            width: badge.isUnlocked ? 1.5 : 1,
          ),
          boxShadow: badge.isUnlocked
              ? [
                  BoxShadow(
                    color: badge.color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badge.isUnlocked
                    ? badge.color.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                badge.icon,
                color: badge.isUnlocked ? badge.color : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              badge.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: badge.isUnlocked
                    ? (isDark ? DesignTokens.inkDark : DesignTokens.inkLight)
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Progress text
            Text(
              badge.isUnlocked ? 'Unlocked!' : badge.unlockProgress,
              style: theme.textTheme.bodySmall?.copyWith(
                color: badge.isUnlocked
                    ? DesignTokens.success
                    : (isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight),
                fontSize: 11,
                fontWeight: badge.isUnlocked ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: badge.progress,
              backgroundColor: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
              color: badge.isUnlocked ? badge.color : Colors.grey,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeInfo badge) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _BadgeDetailsDialog(badge: badge),
    );
  }
}

class _BadgeDetailsDialog extends StatefulWidget {
  const _BadgeDetailsDialog({required this.badge});
  final BadgeInfo badge;

  @override
  State<_BadgeDetailsDialog> createState() => _BadgeDetailsDialogState();
}

class _BadgeDetailsDialogState extends State<_BadgeDetailsDialog> {
  final GlobalKey _shareKey = GlobalKey();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final b = widget.badge;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shareable card view (wrapped in RepaintBoundary)
            RepaintBoundary(
              key: _shareKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.paperDark : Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  border: Border.all(
                    color: b.isUnlocked ? b.color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: b.isUnlocked ? b.color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        b.icon,
                        color: b.isUnlocked ? b.color : Colors.grey,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      b.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      b.isUnlocked ? '🏆 Achievement Unlocked!' : '🔒 Progress: ${b.unlockProgress}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: b.isUnlocked ? DesignTokens.success : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: b.progress,
                      backgroundColor: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                      color: b.isUnlocked ? b.color : Colors.grey,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nili Planner'.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                        letterSpacing: 1.5,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Share / Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                if (b.isUnlocked)
                  FilledButton.icon(
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share Badge'),
                    style: FilledButton.styleFrom(
                      backgroundColor: b.color,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSharing ? null : _shareImage,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/badge_${widget.badge.id}.png').create();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'I unlocked the "${widget.badge.title}" badge on Nili Personal Planner! 🏆✨',
      );
    } catch (e) {
      debugPrint('Error sharing badge: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}
