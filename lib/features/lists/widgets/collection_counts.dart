import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../repositories/item_repository.dart';
import '../templates/template_registry.dart';

/// Shows an elegant progress bar for completed items in a collection.
class CollectionProgressBar extends ConsumerWidget {
  const CollectionProgressBar({
    required this.collectionId,
    required this.template,
    required this.mainColor,
    super.key,
  });

  final int collectionId;
  final TemplateDef template;
  final Color mainColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_itemsProvider(collectionId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return itemsAsync.when(
      loading: () => const SizedBox(height: 4),
      error: (e, st) => const SizedBox(height: 4),
      data: (items) {
        if (items.isEmpty) {
          return const SizedBox(height: 4);
        }
        final total = items.length;
        final done = items.where((i) => i.status == template.doneStatus).length;
        final progress = total > 0 ? done / total : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$done/$total completed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress == 1.0 
                      ? DesignTokens.success 
                      : mainColor,
                ),
                minHeight: 4,
              ),
            ),
          ],
        );
      },
    );
  }
}

final _itemsProvider = StreamProvider.family<List<Item>, int>((
  ref,
  collectionId,
) {
  return ref.watch(itemRepositoryProvider).watchItems(collectionId);
});
