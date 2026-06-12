import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/event_repository.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';
import '../finance/repositories/transaction_repository.dart';
import '../finance/widgets/transaction_tile.dart';
import '../gym/gym_screen.dart';
import '../lists/repositories/item_repository.dart';
import '../meals/meal_slot_repository.dart';
import 'day_tag_picker.dart';
import 'event_edit_sheet.dart';

class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({required this.date, super.key});

  final String date; // YYYY-MM-DD

  static void show(BuildContext context, String date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _DayDetailSheetContent(
          date: date,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scaffold fallback for direct link routing
    return Scaffold(
      body: _DayDetailSheetContent(date: date),
    );
  }
}

// ── Sheet Content ─────────────────────────────────────────────────────────────

class _DayDetailSheetContent extends ConsumerWidget {
  const _DayDetailSheetContent({required this.date, this.scrollController});

  final String date;
  final ScrollController? scrollController;

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final parsed = _parseDate(date);
    final headerFmt = DateFormat('EEEE, MMMM d, yyyy');

    final tagsAsync = ref.watch(dayTagsFutureProvider(date));
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
        child: Column(
          children: [
            // ── DayWash Header + Drag Handle ──
            tagsAsync.when(
              loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox(height: 140),
              data: (tags) {
                final washColors = tags.map((t) => AppColors.forTagName(t.name)).toList();
                return Container(
                  width: double.infinity,
                  decoration: DayWashDecoration(tagColors: washColors, isDark: isDark),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              headerFmt.format(parsed),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: inkColor,
                              ),
                            ),
                          ),
                          FloatingActionButton.small(
                            heroTag: 'day_detail_fab_$date',
                            backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                            foregroundColor: Colors.white,
                            onPressed: () => EventEditSheet.show(context, initialDate: date),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Sections List ──
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 88),
                children: [
                  // Tags Editor
                  const SectionHeader(title: 'Tags Catalog'),
                  const SizedBox(height: 8),
                  DayTagPicker(date: date),
                  const SizedBox(height: 24),

                  // Events
                  const SectionHeader(title: 'Scheduled Events'),
                  _EventsSection(date: date),
                  const SizedBox(height: 24),

                  // Finance
                  const SectionHeader(title: 'Finance (Planned & Forecast)'),
                  _FinanceSection(date: date),
                  const SizedBox(height: 24),

                  // Meals
                  const SectionHeader(title: 'Meals Menu'),
                  _MealsSection(date: date),
                  const SizedBox(height: 24),

                  // Gym
                  const SectionHeader(title: 'Fitness & Gym Session'),
                  DayDetailGymSection(date: date),
                  const SizedBox(height: 24),

                  // Due items
                  const SectionHeader(title: 'Chore Deadlines & Tasks'),
                  _DueItemsSection(date: date),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day Tags Future Provider ──
final dayTagsFutureProvider = FutureProvider.autoDispose.family<List<Tag>, String>((ref, date) {
  return ref.watch(dayRepositoryProvider).getTagsForDate(date);
});

// ── Custom Flat List Tile Widget (Left Category-Colored Bar) ──────────────────

class FlatListTile extends StatelessWidget {
  const FlatListTile({
    required this.title,
    required this.categoryColor,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Color categoryColor;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight;
    final lineColor = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: BorderSide(color: categoryColor, width: 5),
          top: BorderSide(color: lineColor, width: 1),
          right: BorderSide(color: lineColor, width: 1),
          bottom: BorderSide(color: lineColor, width: 1),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}

// ── Events section ─────────────────────────────────────────────────────────────

final _eventsForDateFutureProvider = FutureProvider.autoDispose.family<List<EventOccurrence>, DateTime>(
  (ref, day) => ref.watch(eventRepositoryProvider).expandOccurrences(day, day),
);

class _EventsSection extends ConsumerWidget {
  const _EventsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = _parseDate(date);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final occAsync = ref.watch(_eventsForDateFutureProvider(day));

    return occAsync.when(
      loading: () => const SizedBox(height: 20, child: LinearProgressIndicator(minHeight: 2)),
      error: (e, _) => Text('Error loading events: $e'),
      data: (occs) {
        if (occs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No events today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: occs.map((occ) {
            final e = occ.event;
            final timeStr = e.startTime != null
                ? '${e.startTime}${e.endTime != null ? ' – ${e.endTime}' : ''}'
                : null;

            final catColor = AppColors.forTagName(e.category);

            return FlatListTile(
              categoryColor: catColor,
              title: Text(
                e.title,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: timeStr != null ? Text(timeStr) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.category.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => EventEditSheet.show(context, existing: e),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

// ── Finance section ────────────────────────────────────────────────────────────

class _FinanceSection extends ConsumerWidget {
  const _FinanceSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_transactionsForDateFutureProvider(date));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return txAsync.when(
      loading: () => const SizedBox(height: 20, child: LinearProgressIndicator(minHeight: 2)),
      error: (e, _) => Text('Error: $e'),
      data: (txs) {
        if (txs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No transactions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: txs.map((tx) {
            final formattedAmount = CurrencyFormatter.format(tx.amountCents);
            final sign = tx.direction == 'in' ? '+' : '–';
            final color = tx.direction == 'in' ? DesignTokens.success : DesignTokens.danger;

            return FlatListTile(
              categoryColor: DesignTokens.sage,
              title: Text(
                tx.note ?? tx.category,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(tx.category),
              trailing: Text(
                '$sign$formattedAmount',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Meals Section ─────────────────────────────────────────────────────────────

class _MealsSection extends ConsumerWidget {
  const _MealsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealSlotsAsync = ref.watch(_mealsForDateStreamProvider(date));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return mealSlotsAsync.when(
      loading: () => const SizedBox(height: 20, child: LinearProgressIndicator(minHeight: 2)),
      error: (e, _) => Text('Error: $e'),
      data: (slots) {
        if (slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No meals planned today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return FutureBuilder<List<Recipe>>(
          future: ref.read(appDatabaseProvider).select(ref.read(appDatabaseProvider).recipes).get(),
          builder: (context, snapshot) {
            final recipes = snapshot.data ?? [];
            final recipeMap = {for (final r in recipes) r.id: r};

            return Column(
              children: slots.map((slot) {
                final recipe = slot.recipeId != null ? recipeMap[slot.recipeId] : null;
                final recipeName = recipe?.name ?? 'No recipe selected';

                return FlatListTile(
                  categoryColor: DesignTokens.peach,
                  title: Text(
                    recipeName,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${slot.slot.toUpperCase()} · ${slot.status}'),
                  trailing: slot.status == 'accepted'
                      ? TextButton(
                          onPressed: () => ref
                              .read(mealSlotRepositoryProvider)
                              .updateStatus(slot.date, slot.slot, 'eaten'),
                          child: const Text('Mark Eaten'),
                        )
                      : null,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

// ── Due Items Section ──────────────────────────────────────────────────────────

class _DueItemsSection extends ConsumerWidget {
  const _DueItemsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_itemsForDateStreamProvider(date));
    final theme = Theme.of(context);

    return itemsAsync.when(
      loading: () => const SizedBox(height: 20, child: LinearProgressIndicator(minHeight: 2)),
      error: (e, _) => Text('Error: $e'),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No items due today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: items.map((item) {
            final isCompleted = item.status == 'done';
            return FlatListTile(
              categoryColor: DesignTokens.lavender,
              leading: Checkbox(
                value: isCompleted,
                onChanged: (val) {
                  ref.read(itemRepositoryProvider).toggleItemStatus(
                        item.id,
                        doneStatus: 'done',
                        openStatus: 'open',
                      );
                },
              ),
              title: Text(
                item.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text('Priority: ${item.priority ?? 'normal'}'),
              trailing: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => context.push('/collection/${item.collectionId}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

final _transactionsForDateFutureProvider = FutureProvider.autoDispose.family<List<Transaction>, String>(
  (ref, date) => ref.watch(transactionRepositoryProvider).getByDate(date),
);

final _mealsForDateStreamProvider = StreamProvider.autoDispose.family<List<MealSlot>, String>(
  (ref, date) {
    final db = ref.watch(appDatabaseProvider);
    return (db.select(db.mealSlots)..where((s) => s.date.equals(date))).watch();
  },
);

final _itemsForDateStreamProvider = StreamProvider.autoDispose.family<List<Item>, String>(
  (ref, date) {
    final db = ref.watch(appDatabaseProvider);
    return (db.select(db.items)..where((i) => i.dueDate.equals(date))).watch();
  },
);

