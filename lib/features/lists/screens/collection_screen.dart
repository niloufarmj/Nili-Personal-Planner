import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/design/design.dart';
import '../repositories/collection_repository.dart';
import '../repositories/item_repository.dart';
import '../templates/template_registry.dart';
import '../widgets/item_edit_sheet.dart';
import '../widgets/subtask_list.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({required this.collectionId, super.key});

  final int collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collAsync = ref.watch(_collectionProvider(collectionId));
    final itemsAsync = ref.watch(_collectionItemsProvider(collectionId));

    return collAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (collection) {
        if (collection == null) {
          return const Scaffold(
            body: Center(child: Text('Collection not found')),
          );
        }
        final template = TemplateRegistry.get(collection.template);

        return Scaffold(
          appBar: AppBar(title: Text(collection.name)),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add item',
            onPressed: () => _openAddSheet(context, ref, collection, template),
            child: const Icon(Icons.add),
          ),
          body: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: template.icon,
                  message: 'No items yet',
                  hint:
                      'Tap + to add your first ${template.label.toLowerCase()} item.',
                  action: () =>
                      _openAddSheet(context, ref, collection, template),
                  actionLabel: 'Add item',
                );
              }
              return _ItemList(
                items: items,
                collection: collection,
                template: template,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openAddSheet(
    BuildContext context,
    WidgetRef ref,
    Collection collection,
    TemplateDef template,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemEditSheet(collection: collection, template: template),
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final _collectionProvider = StreamProvider.family<Collection?, int>((ref, id) {
  return ref
      .watch(collectionRepositoryProvider)
      .watchAll(includeArchived: true)
      .map((cols) {
        try {
          return cols.firstWhere((c) => c.id == id);
        } catch (_) {
          return null;
        }
      });
});

final _collectionItemsProvider = StreamProvider.family<List<Item>, int>((
  ref,
  collectionId,
) {
  return ref.watch(itemRepositoryProvider).watchItems(collectionId);
});

// ── Item list ─────────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.collection,
    required this.template,
  });

  final List<Item> items;
  final Collection collection;
  final TemplateDef template;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      itemCount: items.length,
      itemBuilder: (context, i) =>
          _ItemTile(item: items[i], collection: collection, template: template),
    );
  }
}

// ── Single item tile ──────────────────────────────────────────────────────────

class _ItemTile extends ConsumerStatefulWidget {
  const _ItemTile({
    required this.item,
    required this.collection,
    required this.template,
  });

  final Item item;
  final Collection collection;
  final TemplateDef template;

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final template = widget.template;
    final repo = ref.read(itemRepositoryProvider);

    final isDone = item.status == template.doneStatus;

    return Dismissible(
      key: ValueKey(item.id),
      background: _swipeBackground(
        color: Colors.green.shade700,
        icon: Icons.check,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        color: Colors.red.shade700,
        icon: Icons.delete_outline,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Capture messenger before the await to avoid async-gap context use.
          final messenger = ScaffoldMessenger.of(context);
          await repo.toggleItemStatus(
            item.id,
            doneStatus: template.doneStatus,
            openStatus: template.openStatus,
          );
          if (mounted) _showUndoSnackbar(messenger, ref, item, template);
          return false; // tile stays; status updated reactively
        } else {
          // Swipe left = delete
          return _confirmDelete(context);
        }
      },
      onDismissed: (_) => repo.deleteItem(item.id),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _openEditSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status checkbox / icon
                GestureDetector(
                  onTap: () => repo.toggleItemStatus(
                    item.id,
                    doneStatus: template.doneStatus,
                    openStatus: template.openStatus,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: Icon(
                      isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isDone
                          ? Colors.green.shade600
                          : Theme.of(context).colorScheme.outline,
                      size: 22,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: isDone
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          StatusChip(status: item.status, compact: true),
                          if (template.fields.priority && item.priority != null)
                            PriorityBadge(priority: item.priority!),
                          if (template.fields.dueDate && item.dueDate != null)
                            _DueDateChip(dueDate: item.dueDate!),
                          if (template.fields.plannedCost &&
                              item.plannedCostCents != null)
                            _CostChip(cents: item.plannedCostCents!),
                        ],
                      ),
                    ],
                  ),
                ),
                // Subtask expand toggle
                if (template.fields.subtasks)
                  IconButton(
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            // Subtask inline list
            if (template.fields.subtasks && _expanded)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 6),
                child: SubtaskList(itemId: item.id),
              ),
            // Images for upgrade template
            if (template.fields.imageBefore || template.fields.imageAfter)
              _ImageRow(
                imageBefore: item.imageBefore,
                imageAfter: item.imageAfter,
              ),
          ],
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) => Container(
    color: color,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Icon(icon, color: Colors.white, size: 28),
  );

  Future<bool> _confirmDelete(BuildContext context) async {
    return ConfirmDialog.show(
      context,
      title: 'Delete "${widget.item.title}"?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
  }

  void _showUndoSnackbar(
    ScaffoldMessengerState messenger,
    WidgetRef ref,
    Item item,
    TemplateDef template,
  ) {
    final repo = ref.read(itemRepositoryProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          item.status == template.doneStatus
              ? '"${item.title}" marked done'
              : '"${item.title}" reopened',
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.toggleItemStatus(
            item.id,
            doneStatus: template.doneStatus,
            openStatus: template.openStatus,
          ),
        ),
      ),
    );
  }

  Future<void> _openEditSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemEditSheet(
        collection: widget.collection,
        template: widget.template,
        item: widget.item,
      ),
    );
  }
}

// ── Small chips ───────────────────────────────────────────────────────────────

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({required this.dueDate});

  final String dueDate;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(dueDate);
    final label = date != null ? DateFormat('d MMM').format(date) : dueDate;
    final isOverdue = date != null && date.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade100 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 10,
            color: isOverdue ? Colors.red.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isOverdue ? Colors.red.shade700 : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostChip extends StatelessWidget {
  const _CostChip({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final amount = (cents / 100).toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '€$amount',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.teal.shade700),
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({this.imageBefore, this.imageAfter});

  final String? imageBefore;
  final String? imageAfter;

  @override
  Widget build(BuildContext context) {
    if (imageBefore == null && imageAfter == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (imageBefore != null)
            _ImageSlot(path: imageBefore!, label: 'Before'),
          if (imageAfter != null) _ImageSlot(path: imageAfter!, label: 'After'),
        ],
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({required this.path, required this.label});

  final String path;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              path,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_outlined, size: 28),
              ),
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
