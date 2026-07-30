import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/design/design.dart';
import '../../meals/groceries_service.dart';
import '../repositories/collection_repository.dart';
import '../repositories/item_repository.dart';
import '../templates/template_registry.dart';
import '../widgets/item_edit_sheet.dart';
import '../widgets/subtask_list.dart';

/// Helper to determine whether a list item is completed / in stock.
bool _isItemDone(Item item, TemplateDef template) {
  final s = item.status.toLowerCase();
  return s == template.doneStatus.toLowerCase() ||
      s == 'done' ||
      s == 'bought' ||
      template.statusDef(item.status).isDone;
}

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({required this.collectionId, super.key});

  final int collectionId;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  // Filter for shopping template collections: 'all', 'need', 'have'
  String _stockFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final collAsync = ref.watch(_collectionProvider(widget.collectionId));
    final itemsAsync = ref.watch(_collectionItemsProvider(widget.collectionId));

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

        // Auto-sync ingredients if this is a shopping/groceries collection
        if (collection.template == 'shopping') {
          Future.microtask(
            () => ref
                .read(groceriesServiceProvider)
                .syncAllIngredientsToGroceriesList(targetCollectionId: collection.id),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(collection.name),
            actions: [
              if (collection.template == 'shopping')
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync all ingredients to this list',
                  onPressed: () async {
                    await ref
                        .read(groceriesServiceProvider)
                        .syncAllIngredientsToGroceriesList(targetCollectionId: collection.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Synced all catalog ingredients into Groceries list!'),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
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
                  hint: collection.template == 'shopping'
                      ? 'Tap "Populate All Ingredients" or + to add items.'
                      : 'Tap + to add your first ${template.label.toLowerCase()} item.',
                  action: () async {
                    if (collection.template == 'shopping') {
                      await ref
                          .read(groceriesServiceProvider)
                          .syncAllIngredientsToGroceriesList(targetCollectionId: collection.id);
                    } else {
                      _openAddSheet(context, ref, collection, template);
                    }
                  },
                  actionLabel: collection.template == 'shopping'
                      ? 'Populate All Ingredients'
                      : 'Add item',
                );
              }

              // Apply stock filter for shopping collections
              final filteredItems = items.where((i) {
                if (collection.template != 'shopping') return true;
                final isDone = _isItemDone(i, template);
                if (_stockFilter == 'need') return !isDone;
                if (_stockFilter == 'have') return isDone;
                return true;
              }).toList();

              return Column(
                children: [
                  if (collection.template == 'shopping') ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'all',
                            label: Text('All'),
                            icon: Icon(Icons.format_list_bulleted, size: 16),
                          ),
                          ButtonSegment<String>(
                            value: 'need',
                            label: Text('Need to buy 🛒'),
                          ),
                          ButtonSegment<String>(
                            value: 'have',
                            label: Text('In stock ✅'),
                          ),
                        ],
                        selected: {_stockFilter},
                        onSelectionChanged: (sel) {
                          setState(() => _stockFilter = sel.first);
                        },
                      ),
                    ),
                  ],
                  Expanded(
                    child: filteredItems.isEmpty
                        ? EmptyState(
                            icon: Icons.shopping_bag_outlined,
                            message: _stockFilter == 'need'
                                ? 'Everything is in stock! 🎉'
                                : 'No items matching filter',
                            hint: 'Switch tab or tap + to add items',
                          )
                        : _ItemList(
                            items: filteredItems,
                            collection: collection,
                            template: template,
                          ),
                  ),
                ],
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

    final isDone = _isItemDone(item, template);
    final isShopping = template.id == 'shopping';
    final hasImage =
        item.imageBefore != null && File(item.imageBefore!).existsSync();

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
          final messenger = ScaffoldMessenger.of(context);
          final ok = await _handleStatusToggle();
          if (ok && mounted) _showUndoSnackbar(messenger, ref, item, template);
          return false; // tile stays; status updated reactively
        } else {
          // Swipe left = delete
          return _confirmDelete(context);
        }
      },
      onDismissed: (_) => repo.deleteItem(item.id),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        // For shopping template: tap ONLY toggles state
        onTap: () => isShopping ? _handleStatusToggle() : _openEditSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status checkbox / icon
                GestureDetector(
                  onTap: () => _handleStatusToggle(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
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
                          if (isShopping)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDone ? Colors.green : Colors.orange,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDone ? Icons.check_circle : Icons.remove_shopping_cart,
                                    size: 10,
                                    color: isDone ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isDone ? 'In stock' : 'Need to buy',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDone ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            StatusChip(status: item.status, compact: true),
                          if (template.fields.priority && item.priority != null)
                            PriorityBadge(priority: item.priority!),
                          if (template.fields.dueDate && item.dueDate != null)
                            _DueDateChip(dueDate: item.dueDate!),
                          // Do NOT display planned cost chip for shopping template!
                          if (!isShopping && template.fields.plannedCost && item.plannedCostCents != null)
                            _CostChip(cents: item.plannedCostCents!),
                        ],
                      ),
                    ],
                  ),
                ),
                // Small circular ingredient image on the right side
                if (hasImage)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: FileImage(File(item.imageBefore!)),
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
            if (_expanded && template.fields.subtasks) ...[
              const Divider(height: 12),
              SubtaskList(itemId: item.id),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _handleStatusToggle() async {
    final template = widget.template;
    final repo = ref.read(itemRepositoryProvider);
    final item = widget.item;

    final isDone = _isItemDone(item, template);
    final newStatus = isDone ? template.openStatus : template.doneStatus;

    await repo.updateItem(
      item.copyWith(
        status: newStatus,
        doneDate: Value(!isDone ? _todayIso() : null),
      ),
    );
    return true;
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemEditSheet(
        collection: widget.collection,
        template: widget.template,
        item: widget.item,
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('Are you sure you want to delete "${widget.item.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showUndoSnackbar(
    ScaffoldMessengerState messenger,
    WidgetRef ref,
    Item item,
    TemplateDef template,
  ) {
    messenger.removeCurrentSnackBar();
    final isDone = _isItemDone(item, template);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isDone
              ? 'Marked "${item.title}" as in stock'
              : 'Marked "${item.title}" as need to buy',
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(itemRepositoryProvider).updateItem(
                  item.copyWith(
                    status: item.status,
                    doneDate: Value(item.doneDate),
                  ),
                );
          },
        ),
      ),
    );
  }

  static Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  static String _todayIso() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

// ── Utility Chips ──────────────────────────────────────────────────────────────

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({required this.dueDate});
  final String dueDate;

  @override
  Widget build(BuildContext context) {
    final isOverdue = _checkOverdue(dueDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 10,
            color: isOverdue ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 3),
          Text(
            _formatDate(dueDate),
            style: TextStyle(
              fontSize: 10,
              color: isOverdue ? Colors.red : Colors.blue,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static bool _checkOverdue(String isoDate) {
    try {
      final due = DateTime.parse(isoDate);
      final today = DateTime.now();
      final todayClean = DateTime(today.year, today.month, today.day);
      return due.isBefore(todayClean);
    } catch (_) {
      return false;
    }
  }

  static String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return isoDate;
    }
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
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Text(
        '\$$amount',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.purple,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
