import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../repositories/item_repository.dart';
import '../templates/template_registry.dart';

/// Shows "X open · Y done" counts for a collection card.
class CollectionCounts extends ConsumerWidget {
  const CollectionCounts({
    required this.collectionId,
    required this.template,
    super.key,
  });

  final int collectionId;
  final TemplateDef template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_itemsProvider(collectionId));
    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (items) {
        final open = items.where((i) => i.status != template.doneStatus).length;
        final done = items.where((i) => i.status == template.doneStatus).length;
        return Text(
          '$open open · $done done',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
