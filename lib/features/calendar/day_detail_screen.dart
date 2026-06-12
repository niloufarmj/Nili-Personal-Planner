import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/event_repository.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = _parseDate(date);
    final headerFmt = DateFormat('EEEE, MMMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(headerFmt.format(parsed))),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'day_detail_fab',
        tooltip: 'Add event',
        onPressed: () => EventEditSheet.show(context, initialDate: date),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tags ──────────────────────────────────────────────────────
          const SectionHeader(title: 'Tags'),
          const SizedBox(height: 8),
          DayTagPicker(date: date),
          const SizedBox(height: 20),

          // ── Events ────────────────────────────────────────────────────
          const SectionHeader(title: 'Events'),
          const SizedBox(height: 8),
          _EventsSection(date: date),
          const SizedBox(height: 20),

          // ── Finance (planned transactions) ────────────────────────────
          const SectionHeader(title: 'Finance'),
          const SizedBox(height: 8),
          _FinanceSection(date: date),
          const SizedBox(height: 20),

          // ── Meals ─────────────────────────────────────────────────────
          const SectionHeader(title: 'Meals'),
          const SizedBox(height: 8),
          _MealsSection(date: date),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Gym'),
          DayDetailGymSection(date: date),
          const SizedBox(height: 20),

          // ── Due items ─────────────────────────────────────────────────
          const SectionHeader(title: 'Due items'),
          const SizedBox(height: 8),
          _DueItemsSection(date: date),
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
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

    final occAsync = ref.watch(_eventsForDateFutureProvider(day));

    return occAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error loading events: $e'),
      data: (occs) {
        if (occs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
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
            return AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title),
                subtitle: timeStr != null ? Text(timeStr) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(e.category),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () =>
                          EventEditSheet.show(context, existing: e),
                    ),
                  ],
                ),
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

final _transactionsForDateFutureProvider = FutureProvider.autoDispose.family<List<Transaction>, String>(
  (ref, date) => ref.watch(transactionRepositoryProvider).getByDate(date),
);

// ── Finance section ────────────────────────────────────────────────────────────

class _FinanceSection extends ConsumerWidget {
  const _FinanceSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_transactionsForDateFutureProvider(date));

    return txAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (txs) {
        if (txs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'No transactions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: txs.map((tx) => TransactionTile(transaction: tx)).toList(),
        );
      },
    );
  }
}

final _mealsForDateStreamProvider = StreamProvider.autoDispose.family<List<MealSlot>, String>(
  (ref, date) {
    final db = ref.watch(appDatabaseProvider);
    return (db.select(db.mealSlots)..where((s) => s.date.equals(date))).watch();
  },
);

// ── Meals Section ─────────────────────────────────────────────────────────────

class _MealsSection extends ConsumerWidget {
  const _MealsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealSlotsAsync = ref.watch(_mealsForDateStreamProvider(date));

    return mealSlotsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (slots) {
        if (slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
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

                return AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${slot.slot.toUpperCase()}: $recipeName'),
                    subtitle: Text('Status: ${slot.status}'),
                    trailing: slot.status == 'accepted'
                        ? TextButton(
                            onPressed: () => ref
                                .read(mealSlotRepositoryProvider)
                                .updateStatus(slot.date, slot.slot, 'eaten'),
                            child: const Text('Mark Eaten'),
                          )
                        : null,
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

final _itemsForDateStreamProvider = StreamProvider.autoDispose.family<List<Item>, String>(
  (ref, date) {
    final db = ref.watch(appDatabaseProvider);
    return (db.select(db.items)..where((i) => i.dueDate.equals(date))).watch();
  },
);

// ── Due Items Section ──────────────────────────────────────────────────────────

class _DueItemsSection extends ConsumerWidget {
  const _DueItemsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_itemsForDateStreamProvider(date));

    return itemsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'No items due today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: items.map((item) {
            final isCompleted = item.status == 'done';
            return AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
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
                  style: TextStyle(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text('Priority: ${item.priority ?? 'normal'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => context.push('/collection/${item.collectionId}'),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
