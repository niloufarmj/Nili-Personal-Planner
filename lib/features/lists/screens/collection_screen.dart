import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/design/design.dart';
import '../../../core/services/image_service.dart';
import '../../meals/groceries_service.dart';
import '../helpers/job_status_helper.dart';
import '../repositories/collection_repository.dart';
import '../repositories/item_repository.dart';
import '../templates/template_registry.dart';
import '../widgets/item_edit_sheet.dart';
import '../widgets/job_analytics_widget.dart';
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
  // Segmented view for job template: 0 = Items List, 1 = Analytics & Charts
  int _jobSelectedTab = 0;
  // Media template view & filter state
  String _mediaFilter = 'all'; // 'all', 'movie', 'series', 'backlog', 'done'
  String _mediaSearchQuery = '';
  String _mediaViewMode = 'grid'; // 'grid' vs 'list'

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
        final isGroceries =
            collection.template == 'groceries' ||
            collection.name == 'Groceries';

        // Run global item deduplication microtask
        Future.microtask(
          () => ref.read(itemRepositoryProvider).deduplicateAllItems(),
        );

        final coverPath = getCoverImageForCollection(
          collectionName: collection.name,
          template: collection.template,
          coverImage: collection.coverImage,
        );
        final hasCover = hasDisplayableImage(coverPath);

        return Scaffold(
          appBar: AppBar(
            title: Text(collection.name),
            actions: [
              if (template.id == 'media')
                IconButton(
                  icon: Icon(
                    _mediaViewMode == 'grid'
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                  ),
                  tooltip: _mediaViewMode == 'grid'
                      ? 'Switch to List View'
                      : 'Switch to Grid View',
                  onPressed: () => setState(() {
                    _mediaViewMode = _mediaViewMode == 'grid' ? 'list' : 'grid';
                  }),
                ),
              if (isGroceries)
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync all ingredients to this list',
                  onPressed: () async {
                    await ref
                        .read(groceriesServiceProvider)
                        .syncAllIngredientsToGroceriesList(
                          targetCollectionId: collection.id,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Synced all catalog ingredients into Groceries list!',
                          ),
                        ),
                      );
                    }
                  },
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) =>
                    _handleCoverAction(context, ref, collection, val),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'set_cover',
                    child: Text(
                      hasCover ? 'Change Header Photo' : 'Set Header Photo',
                    ),
                  ),
                  if (hasCover)
                    const PopupMenuItem(
                      value: 'remove_cover',
                      child: Text('Remove Header Photo'),
                    ),
                  const PopupMenuItem(
                    value: 'delete_list',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete List', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add item',
            onPressed: () => _openAddSheet(context, ref, collection, template),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              if (hasCover) _CollectionHeaderBanner(coverImage: coverPath),
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) {
                    if (items.isEmpty) {
                      return EmptyState(
                        icon: template.icon,
                        message: 'No items yet',
                        hint: isGroceries
                            ? 'Tap "Populate All Ingredients" or + to add items.'
                            : 'Tap + to add your first ${template.label.toLowerCase()} item.',
                        action: () async {
                          if (isGroceries) {
                            await ref
                                .read(groceriesServiceProvider)
                                .syncAllIngredientsToGroceriesList(
                                  targetCollectionId: collection.id,
                                );
                          } else {
                            _openAddSheet(context, ref, collection, template);
                          }
                        },
                        actionLabel: isGroceries
                            ? 'Populate All Ingredients'
                            : 'Add item',
                      );
                    }

                    // Apply filters for groceries or media collections
                    final filteredItems = items.where((i) {
                      if (isGroceries) {
                        final isDone = _isItemDone(i, template);
                        if (_stockFilter == 'need') return !isDone;
                        if (_stockFilter == 'have') return isDone;
                        return true;
                      }
                      if (template.id == 'media') {
                        final defaultKind = collection.name.toLowerCase().contains('book') ? 'book' : 'movie';
                        final kind = (i.meta?['kind'] ?? defaultKind).toString().toLowerCase();
                        final isDone = _isItemDone(i, template);
                        if (_mediaFilter == 'movie' && kind != 'movie') return false;
                        if (_mediaFilter == 'series' && kind != 'series') return false;
                        if (_mediaFilter == 'book' && kind != 'book') return false;
                        if (_mediaFilter == 'game' && kind != 'game') return false;
                        if (_mediaFilter == 'backlog' && isDone) return false;
                        if (_mediaFilter == 'done' && !isDone) return false;

                        if (_mediaSearchQuery.trim().isNotEmpty) {
                          final q = _mediaSearchQuery.trim().toLowerCase();
                          if (!i.title.toLowerCase().contains(q)) return false;
                        }
                      }
                      return true;
                    }).toList();

                    return Column(
                      children: [
                        if (isGroceries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'all',
                                  label: Text('All'),
                                  icon: Icon(
                                    Icons.format_list_bulleted,
                                    size: 16,
                                  ),
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
                        if (template.id == 'media') ...[
                          Builder(builder: (ctx) {
                            final kinds = items
                                .map((i) {
                                  final defaultKind = collection.name.toLowerCase().contains('book')
                                      ? 'book'
                                      : 'movie';
                                  return (i.meta?['kind'] ?? defaultKind).toString().toLowerCase();
                                })
                                .toSet();
                            final isBooksOnly = kinds.length == 1 && kinds.contains('book');
                            final hintText = isBooksOnly
                                ? 'Search books...'
                                : 'Search media...';

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                                  child: TextField(
                                    onChanged: (val) => setState(() => _mediaSearchQuery = val),
                                    decoration: InputDecoration(
                                      hintText: hintText,
                                      prefixIcon: const Icon(Icons.search, size: 20),
                                      suffixIcon: _mediaSearchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () => setState(() => _mediaSearchQuery = ''),
                                            )
                                          : null,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: Row(
                                    children: [
                                      _FilterChipBtn(
                                        label: 'All 🍿',
                                        selected: _mediaFilter == 'all',
                                        onTap: () => setState(() => _mediaFilter = 'all'),
                                      ),
                                      if (kinds.contains('movie')) ...[
                                        const SizedBox(width: 8),
                                        _FilterChipBtn(
                                          label: 'Movies 🎬',
                                          selected: _mediaFilter == 'movie',
                                          onTap: () => setState(() => _mediaFilter = 'movie'),
                                        ),
                                      ],
                                      if (kinds.contains('series')) ...[
                                        const SizedBox(width: 8),
                                        _FilterChipBtn(
                                          label: 'Series 📺',
                                          selected: _mediaFilter == 'series',
                                          onTap: () => setState(() => _mediaFilter = 'series'),
                                        ),
                                      ],
                                      if (kinds.contains('book')) ...[
                                        const SizedBox(width: 8),
                                        _FilterChipBtn(
                                          label: 'Books 📚',
                                          selected: _mediaFilter == 'book',
                                          onTap: () => setState(() => _mediaFilter = 'book'),
                                        ),
                                      ],
                                      if (kinds.contains('game')) ...[
                                        const SizedBox(width: 8),
                                        _FilterChipBtn(
                                          label: 'Games 🎮',
                                          selected: _mediaFilter == 'game',
                                          onTap: () => setState(() => _mediaFilter = 'game'),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      _FilterChipBtn(
                                        label: 'Backlog ⏳',
                                        selected: _mediaFilter == 'backlog',
                                        onTap: () => setState(() => _mediaFilter = 'backlog'),
                                      ),
                                      const SizedBox(width: 8),
                                      _FilterChipBtn(
                                        label: 'Done ✅',
                                        selected: _mediaFilter == 'done',
                                        onTap: () => setState(() => _mediaFilter = 'done'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                        if (template.id == 'job') ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment<int>(
                                  value: 0,
                                  label: Text('Items List'),
                                  icon: Icon(Icons.list_alt, size: 16),
                                ),
                                ButtonSegment<int>(
                                  value: 1,
                                  label: Text('Analytics & Charts'),
                                  icon: Icon(Icons.bar_chart, size: 16),
                                ),
                              ],
                              selected: {_jobSelectedTab},
                              onSelectionChanged: (sel) {
                                setState(() => _jobSelectedTab = sel.first);
                              },
                            ),
                          ),
                        ],
                        Expanded(
                          child: (template.id == 'job' && _jobSelectedTab == 1)
                              ? JobAnalyticsWidget(items: items)
                              : (filteredItems.isEmpty
                                  ? EmptyState(
                                      icon: template.icon,
                                      message: _stockFilter == 'need'
                                          ? 'Everything is in stock! 🎉'
                                          : 'No items matching filter',
                                      hint: 'Switch tab or tap + to add items',
                                    )
                                  : (template.id == 'media'
                                      ? (_mediaViewMode == 'grid'
                                          ? _MediaGridView(
                                              items: filteredItems,
                                              collection: collection,
                                              template: template,
                                            )
                                          : _MediaListView(
                                              items: filteredItems,
                                              collection: collection,
                                              template: template,
                                            ))
                                      : _ItemList(
                                          items: filteredItems,
                                          collection: collection,
                                          template: template,
                                        ))),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCoverAction(
    BuildContext context,
    WidgetRef ref,
    Collection collection,
    String action,
  ) async {
    final repo = ref.read(collectionRepositoryProvider);
    final imageService = ref.read(imageServiceProvider);
    final oldCover = collection.coverImage;

    if (action == 'set_cover') {
      final picked = await imageService.pick(source: ImageSource.gallery);
      if (picked == null) return;
      await repo.setCoverImage(collection.id, picked);
      if (oldCover != null) await imageService.delete(oldCover);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Header photo updated')));
      }
    } else if (action == 'remove_cover') {
      await repo.setCoverImage(collection.id, null);
      if (oldCover != null) await imageService.delete(oldCover);
    } else if (action == 'delete_list') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete List?'),
          content: Text(
            'Are you sure you want to delete "${collection.name}"? This will permanently remove all items inside this list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await repo.delete(collection.id);
        if (context.mounted) Navigator.pop(context);
      }
    }
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

// ── Header banner ─────────────────────────────────────────────────────────────

/// Faint cover-photo banner shown at the top of a list's own screen.
/// Height is fixed and modest so it never crowds out the item list on a
/// phone-sized viewport.
class _CollectionHeaderBanner extends StatelessWidget {
  const _CollectionHeaderBanner({required this.coverImage});

  final String coverImage;

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFor(coverImage);
    if (image == null) return const SizedBox.shrink();

    return SizedBox(
      height: 110,
      width: double.infinity,
      child: Opacity(
        opacity: 0.4,
        child: Image(
          image: image,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox.shrink(),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
    final isGroceries =
        template.id == 'groceries' || widget.collection.name == 'Groceries';
    final hasImage = hasDisplayableImage(item.imageBefore);

    final meta = item.meta;
    final city = meta?['city'] as String?;
    final category = meta?['category'] as String?;
    final hasOpenPosRaw = meta?['has_open_position'];
    final bool? hasOpenPos = (hasOpenPosRaw is bool)
        ? hasOpenPosRaw
        : (hasOpenPosRaw?.toString().toLowerCase() == 'true'
            ? true
            : (hasOpenPosRaw?.toString().toLowerCase() == 'false'
                ? false
                : null));
    final website = meta?['website'] as String?;
    final linkedin = meta?['linkedin'] as String?;
    final email = meta?['email'] as String?;

    final isJob = template.id == 'job';
    final statusDef = template.statusDef(item.status);
    final cardColor = isJob ? statusDef.color.withValues(alpha: 0.04) : null;
    final borderColor = isJob ? statusDef.color.withValues(alpha: 0.5) : null;

    final appliedDate = meta?['applied_date'] as String?;
    final interviewDate = meta?['interview_date'] as String?;
    final rejectedDate = meta?['rejected_date'] as String?;
    final offerDate = meta?['offer_date'] as String?;

    final interviewDays = JobStatusHelper.daysBetween(appliedDate, interviewDate);
    final rejectedDays = JobStatusHelper.daysBetween(appliedDate, rejectedDate);
    final offerDays = JobStatusHelper.daysBetween(appliedDate, offerDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
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
          color: cardColor,
          borderColor: borderColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // For groceries template: tap ONLY toggles state
        // For standard shopping & other templates: tap opens edit/description sheet
        onTap: () =>
            isGroceries ? _handleStatusToggle() : _openEditSheet(context),
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
                          if (isGroceries)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                                    isDone
                                        ? Icons.check_circle
                                        : Icons.remove_shopping_cart,
                                    size: 10,
                                    color: isDone
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isDone ? 'In stock' : 'Need to buy',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDone
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            PopupMenuButton<String>(
                              onSelected: (newStatus) async {
                                final updatedMeta = JobStatusHelper.updateMetaForStatus(
                                  item.meta,
                                  newStatus,
                                );
                                final isDoneStatus = template.statusDef(newStatus).isDone;
                                await repo.updateItem(
                                  item.copyWith(
                                    status: newStatus,
                                    doneDate: Value(isDoneStatus ? _todayIso() : null),
                                    meta: Value(updatedMeta),
                                  ),
                                );
                              },
                              itemBuilder: (ctx) => template.statuses.map((s) {
                                return PopupMenuItem<String>(
                                  value: s.value,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: s.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(s.label),
                                    ],
                                  ),
                                );
                              }).toList(),
                              child: StatusChip(status: item.status, compact: true),
                            ),
                          if (template.fields.priority && item.priority != null)
                            PriorityBadge(priority: item.priority!),
                          if (template.fields.dueDate && item.dueDate != null)
                            _DueDateChip(dueDate: item.dueDate!),
                          if (template.fields.plannedCost &&
                              item.plannedCostCents != null)
                            _CostChip(cents: item.plannedCostCents!),
                          if (template.id == 'job' && meta != null) ...[
                            if (city != null && city.isNotEmpty)
                              _MetaChip(
                                icon: Icons.location_on_outlined,
                                label: city,
                                color: Colors.teal,
                              ),
                            if (category != null && category.isNotEmpty)
                              _MetaChip(
                                icon: Icons.category_outlined,
                                label: category,
                                color: Colors.indigo,
                              ),
                            if (hasOpenPos != null)
                              _MetaChip(
                                icon: hasOpenPos
                                    ? Icons.check_circle_outline
                                    : Icons.send_outlined,
                                label: hasOpenPos
                                    ? 'Open Position'
                                    : 'Unsolicited Application',
                                color: hasOpenPos ? Colors.green : Colors.blueGrey,
                              ),
                            if (website != null && website.isNotEmpty)
                              _MetaChip(
                                icon: Icons.language,
                                label: 'Website',
                                color: Colors.blue,
                              ),
                            if (linkedin != null && linkedin.isNotEmpty)
                              _MetaChip(
                                icon: Icons.link,
                                label: 'LinkedIn',
                                color: Colors.blue.shade700,
                              ),
                            if (email != null && email.isNotEmpty)
                              _MetaChip(
                                icon: Icons.email_outlined,
                                label: email,
                                color: Colors.deepOrange,
                              ),
                            if (appliedDate != null && appliedDate.isNotEmpty)
                              _MetaChip(
                                icon: Icons.calendar_today,
                                label: 'Applied: ${_formatShortDate(appliedDate)}',
                                color: Colors.amber.shade900,
                              ),
                            if (interviewDate != null && interviewDate.isNotEmpty)
                              _MetaChip(
                                icon: Icons.event,
                                label:
                                    'Interview: ${_formatShortDate(interviewDate)}${interviewDays != null ? ' (+$interviewDays d)' : ''}',
                                color: Colors.blue.shade800,
                              ),
                            if (rejectedDate != null && rejectedDate.isNotEmpty)
                              _MetaChip(
                                icon: Icons.cancel_outlined,
                                label:
                                    'Rejected: ${_formatShortDate(rejectedDate)}${rejectedDays != null ? ' (+$rejectedDays d)' : ''}',
                                color: Colors.red.shade800,
                              ),
                            if (offerDate != null && offerDate.isNotEmpty)
                              _MetaChip(
                                icon: Icons.verified_outlined,
                                label:
                                    'Offer: ${_formatShortDate(offerDate)}${offerDays != null ? ' (+$offerDays d)' : ''}',
                                color: Colors.green.shade800,
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Small circular ingredient image on the right side for Groceries
                if (isGroceries && hasImage)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: imageProviderFor(item.imageBefore),
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
            content: Text(
              'Are you sure you want to delete "${widget.item.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
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
            ref
                .read(itemRepositoryProvider)
                .updateItem(
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

String _formatShortDate(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate);
    return DateFormat('d MMM').format(dt);
  } catch (_) {
    return isoDate;
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip Button Widget ───────────────────────────────────────────────

class _FilterChipBtn extends StatelessWidget {
  const _FilterChipBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Media List View (Ingredients Catalog Style) ──────────────────────────────

class _MediaListView extends StatelessWidget {
  const _MediaListView({
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 100),
      itemCount: items.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _MediaListTile(
          item: items[i],
          collection: collection,
          template: template,
        ),
      ),
    );
  }
}

class _MediaListTile extends ConsumerWidget {
  const _MediaListTile({
    required this.item,
    required this.collection,
    required this.template,
  });

  final Item item;
  final Collection collection;
  final TemplateDef template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = _isItemDone(item, template);
    final hasImage = hasDisplayableImage(item.imageBefore);
    final kind = (item.meta?['kind'] ?? 'movie').toString().toLowerCase();

    String emoji = '🎬';
    Color bgTint = const Color(0xFFF4E3B2);
    if (kind == 'series') {
      emoji = '📺';
      bgTint = const Color(0xFFC2BBF0);
    } else if (kind == 'book') {
      emoji = '📚';
      bgTint = const Color(0xFFBFD8C2);
    } else if (kind == 'game') {
      emoji = '🎮';
      bgTint = const Color(0xFFA8BFDD);
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _openEditSheet(context, ref),
      child: Row(
        children: [
          // Status checkbox
          GestureDetector(
            onTap: () => _toggleStatus(ref),
            child: Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? Colors.green.shade600 : Theme.of(context).colorScheme.outline,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Title & badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bgTint.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${kind.toUpperCase()} $emoji',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    StatusChip(status: item.status, compact: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Circular Image Container Avatar (matching Ingredients Catalog!)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgTint.withValues(alpha: 0.4),
              border: Border.all(color: bgTint, width: 1.5),
            ),
            child: hasImage
                ? ClipOval(
                    child: Image(
                      image: imageProviderFor(item.imageBefore)!,
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                    ),
                  )
                : Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          // 3-dots popup menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (val) async {
              if (val == 'edit') {
                _openEditSheet(context, ref);
              } else if (val == 'photo') {
                final path = await ref.read(imageServiceProvider).pick();
                if (path != null) {
                  await ref.read(itemRepositoryProvider).updateItem(
                        item.copyWith(imageBefore: Value(path)),
                      );
                }
              } else if (val == 'delete') {
                await ref.read(itemRepositoryProvider).deleteItem(item.id);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Item'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'photo',
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(hasImage ? 'Change Poster' : 'Add Poster'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemEditSheet(
        collection: collection,
        template: template,
        item: item,
      ),
    );
  }

  Future<void> _toggleStatus(WidgetRef ref) async {
    final repo = ref.read(itemRepositoryProvider);
    final isDone = _isItemDone(item, template);
    final newStatus = isDone ? template.openStatus : template.doneStatus;
    await repo.updateItem(
      item.copyWith(
        status: newStatus,
        doneDate: Value(!isDone ? _todayIso() : null),
      ),
    );
  }

  static String _todayIso() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

// ── Media Grid View (Achievements & Badges Style) ───────────────────────────

class _MediaGridView extends StatelessWidget {
  const _MediaGridView({
    required this.items,
    required this.collection,
    required this.template,
  });

  final List<Item> items;
  final Collection collection;
  final TemplateDef template;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _MediaGridCard(
        item: items[i],
        collection: collection,
        template: template,
      ),
    );
  }
}

class _MediaGridCard extends ConsumerWidget {
  const _MediaGridCard({
    required this.item,
    required this.collection,
    required this.template,
  });

  final Item item;
  final Collection collection;
  final TemplateDef template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = _isItemDone(item, template);
    final hasImage = hasDisplayableImage(item.imageBefore);
    final kind = (item.meta?['kind'] ?? 'movie').toString().toLowerCase();

    String emoji = '🎬';
    Color bgTint = const Color(0xFFF4E3B2);
    if (kind == 'series') {
      emoji = '📺';
      bgTint = const Color(0xFFC2BBF0);
    } else if (kind == 'book') {
      emoji = '📚';
      bgTint = const Color(0xFFBFD8C2);
    }

    return AppCard(
      padding: EdgeInsets.zero,
      color: isDone ? Colors.green.withValues(alpha: 0.05) : null,
      onTap: () => _openEditSheet(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poster top area (~68% height)
          Expanded(
            flex: 68,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: hasImage
                        ? Image(
                            image: imageProviderFor(item.imageBefore)!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  bgTint.withValues(alpha: 0.6),
                                  bgTint.withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 36)),
                                  const SizedBox(height: 4),
                                  Text(
                                    kind.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                // Top-right floating status chip
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDone
                          ? Colors.green.shade700
                          : Colors.deepPurple.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      isDone ? 'DONE ✅' : 'BACKLOG ⏳',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom area (~32% height)
          Expanded(
            flex: 32,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleStatus(ref),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemEditSheet(
        collection: collection,
        template: template,
        item: item,
      ),
    );
  }

  Future<void> _toggleStatus(WidgetRef ref) async {
    final repo = ref.read(itemRepositoryProvider);
    final isDone = _isItemDone(item, template);
    final newStatus = isDone ? template.openStatus : template.doneStatus;
    await repo.updateItem(
      item.copyWith(
        status: newStatus,
        doneDate: Value(!isDone ? _todayIso() : null),
      ),
    );
  }

  static String _todayIso() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
