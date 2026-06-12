import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';
import 'meal_slot_repository.dart';
import 'meal_suggester.dart';
import 'recipe_repository.dart';
import 'shopping_generator.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _selectedWeekProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  // Monday of the current week.
  return _mondayOf(now);
});

final _weekSlotsProvider = StreamProvider.autoDispose
    .family<List<MealSlot>, DateTime>((ref, week) {
      return ref.watch(mealSlotRepositoryProvider).watchWeek(week);
    });

final _weekTagsProvider = FutureProvider.autoDispose
    .family<Map<String, List<Tag>>, DateTime>((ref, week) {
      final dayRepo = ref.watch(dayRepositoryProvider);
      final end = week.add(const Duration(days: 6));
      return dayRepo.watchTagsForRange(week, end).first;
    });

// ── MealsScreen ───────────────────────────────────────────────────────────────

class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedWeek = ref.watch(_selectedWeekProvider);
    final slotsAsync = ref.watch(_weekSlotsProvider(selectedWeek));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Meals — week of ${_fmt(selectedWeek)}',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(_selectedWeekProvider.notifier).state =
                selectedWeek.subtract(const Duration(days: 7)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(_selectedWeekProvider.notifier).state =
                selectedWeek.add(const Duration(days: 7)),
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Recipes',
            onPressed: () => context.push('/recipes'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: slotsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: ShimmerSkeleton(width: double.infinity, height: 300),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (slots) => _WeekGrid(week: selectedWeek, slots: slots),
            ),
          ),
          _BottomActions(week: selectedWeek),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) => DateFormat('d MMM').format(d);
}

// ── Week grid ─────────────────────────────────────────────────────────────────

class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({required this.week, required this.slots});
  final DateTime week;
  final List<MealSlot> slots;

  static const _allSlots = ['breakfast', 'lunch', 'dinner', 'post-gym-shake'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(_weekTagsProvider(week));
    final slotMap = {for (final s in slots) '${s.date}:${s.slot}': s};
    final days = List.generate(7, (i) => week.add(Duration(days: i)));
    final dayFmt = DateFormat('EEE\nd');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return tagsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: ShimmerSkeleton(width: double.infinity, height: 300),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tagsByDate) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    children: [
                      const _Cell(child: SizedBox(width: 80)),
                      ...days.map((d) {
                        final dateStr = _dateStr(d);
                        final tags = tagsByDate[dateStr] ?? [];
                        final tagColors = tags.map((t) => AppColors.forTagName(t.name)).toList();

                        return Container(
                          decoration: DayWashDecoration(
                            tagColors: tagColors,
                            isDark: isDark,
                          ),
                          child: _Cell(
                            child: Column(
                              children: [
                                Text(
                                  dayFmt.format(d),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                                  ),
                                ),
                                if (tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Wrap(
                                      children: tags
                                          .map(
                                            (t) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 2,
                                              ),
                                              child: Icon(
                                                Icons.circle,
                                                size: 6,
                                                color: _tagColor(t.name),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  // One row per slot
                  ..._allSlots.map(
                    (slot) => TableRow(
                      children: [
                        _Cell(
                          child: Text(
                            _slotLabel(slot),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                            ),
                          ),
                        ),
                        ...days.map((d) {
                          final dateStr = _dateStr(d);
                          final key = '$dateStr:$slot';
                          final mealSlot = slotMap[key];
                          final tags = tagsByDate[dateStr] ?? [];
                          final tagColors = tags.map((t) => AppColors.forTagName(t.name)).toList();

                          return Container(
                            decoration: DayWashDecoration(
                              tagColors: tagColors,
                              isDark: isDark,
                            ),
                            child: _MealCell(
                              date: dateStr,
                              slot: slot,
                              mealSlot: mealSlot,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _tagColor(String name) {
    return switch (name) {
      'travel' => const Color(0xFF3EBF6F),
      'gym' => const Color(0xFFEF6C00),
      'work' => const Color(0xFF1565C0),
      _ => const Color(0xFF9E9E9E),
    };
  }

  static String _slotLabel(String s) => switch (s) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'post-gym-shake' => 'Shake',
    _ => s,
  };

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _Cell extends StatelessWidget {
  const _Cell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(4), child: child);
  }
}

class _MealCell extends ConsumerWidget {
  const _MealCell({
    required this.date,
    required this.slot,
    required this.mealSlot,
  });
  final String date;
  final String slot;
  final MealSlot? mealSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = mealSlot == null
        ? Colors.transparent
        : _statusColor(mealSlot!.status);

    return GestureDetector(
      onTap: () => _showSlotActions(context, ref),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(6),
        width: 80,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          border: Border.all(color: statusColor, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: mealSlot?.recipeId != null
            ? _RecipeName(recipeId: mealSlot!.recipeId!)
            : Text(
                mealSlot != null ? mealSlot!.status : '—',
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }

  void _showSlotActions(BuildContext context, WidgetRef ref) {
    final slotRepo = ref.read(mealSlotRepositoryProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mealSlot?.status == 'accepted' ||
                mealSlot?.status == 'suggested') ...[
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Mark eaten'),
                onTap: () async {
                  Navigator.pop(context);
                  await slotRepo.updateStatus(date, slot, 'eaten');
                },
              ),
              ListTile(
                leading: const Icon(Icons.skip_next),
                title: const Text('Mark skipped'),
                onTap: () async {
                  Navigator.pop(context);
                  await slotRepo.updateStatus(date, slot, 'skipped');
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear slot'),
              onTap: () async {
                Navigator.pop(context);
                await slotRepo.delete(date, slot);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String s) => switch (s) {
    'accepted' => Colors.green,
    'eaten' => Colors.blue,
    'skipped' => Colors.grey,
    'suggested' => Colors.orange,
    _ => Colors.grey,
  };
}

class _RecipeName extends ConsumerWidget {
  const _RecipeName({required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(_recipeNameProvider(recipeId));
    return recipeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Text('?'),
      data: (name) => Text(
        name ?? '?',
        style: Theme.of(context).textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

final _recipeNameProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  id,
) async {
  final r = await ref.watch(recipeRepositoryProvider).getById(id);
  return r?.name;
});

// ── Bottom actions ────────────────────────────────────────────────────────────

class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.week});
  final DateTime week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Suggest week'),
                onPressed: () => _suggestWeek(context, ref),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Accept & shop'),
                onPressed: () => _acceptAndShop(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _suggestWeek(BuildContext context, WidgetRef ref) async {
    final recipeRepo = ref.read(recipeRepositoryProvider);
    final dayRepo = ref.read(dayRepositoryProvider);
    final slotRepo = ref.read(mealSlotRepositoryProvider);

    final pool = await recipeRepo.getAll();
    final end = week.add(const Duration(days: 6));
    final tagsByDate = await dayRepo.watchTagsForRange(week, end).first;

    final weekContexts = List.generate(7, (i) {
      final d = week.add(Duration(days: i));
      final dateStr = _dateStr(d);
      return DayContext(
        date: dateStr,
        tagNames: (tagsByDate[dateStr] ?? []).map((t) => t.name).toList(),
      );
    });

    // Load last week's slots as history.
    final prevWeek = week.subtract(const Duration(days: 7));
    final history = await slotRepo.getForWeek(prevWeek);

    final suggestions = MealSuggester(
      random: Random(),
    ).suggest(week: weekContexts, pool: pool, recentHistory: history);

    for (final entry in suggestions.entries) {
      for (final slotEntry in entry.value.entries) {
        if (!slotEntry.value.noMatch && slotEntry.value.recipe != null) {
          await slotRepo.upsert(
            date: entry.key,
            slot: slotEntry.key,
            recipeId: slotEntry.value.recipe!.id,
            status: 'suggested',
          );
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Week suggestions generated!')),
      );
    }
  }

  Future<void> _acceptAndShop(BuildContext context, WidgetRef ref) async {
    final slotRepo = ref.read(mealSlotRepositoryProvider);
    final shopGen = ref.read(shoppingGeneratorProvider);

    await slotRepo.acceptWeek(week);
    final colId = await shopGen.generateForWeek(week);

    if (context.mounted) {
      context.push('/collection/$colId');
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Recipes list screen ───────────────────────────────────────────────────────

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(_allRecipesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipe_fab',
        onPressed: () => context.push('/recipe/new'),
        child: const Icon(Icons.add),
      ),
      body: recipesAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (recipes) {
          if (recipes.isEmpty) {
            return const EmptyState(
              icon: Icons.restaurant_menu,
              message: 'No recipes yet',
              hint: 'Tap + to add your first recipe',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (_, i) {
              final r = recipes[i];
              return AppCard(
                child: ListTile(
                  title: Text(r.name),
                  subtitle: Text(
                    '${r.mealSlot} · ${r.tags.take(3).join(', ')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/recipe/${r.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

final _allRecipesProvider = StreamProvider.autoDispose<List<Recipe>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchAll(),
);

// ── Helpers ───────────────────────────────────────────────────────────────────

DateTime _mondayOf(DateTime d) {
  return d.subtract(Duration(days: d.weekday - 1));
}
