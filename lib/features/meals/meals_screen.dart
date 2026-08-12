import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';
import '../../core/services/image_service.dart';
import 'groceries_service.dart';
import 'meal_slot_repository.dart';
import 'meal_suggester.dart';
import 'nutrition_calculator.dart';
import 'nutrition_profile.dart';
import 'recipe_repository.dart';
import 'shopping_generator.dart';
import 'widgets/nutrition_profile_sheet.dart';

class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
  }

  void _prevWeek() => setState(() {
        _weekStart = _weekStart.subtract(const Duration(days: 7));
      });

  void _nextWeek() => setState(() {
        _weekStart = _weekStart.add(const Duration(days: 7));
      });

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(_weekSlotsProvider(_weekStart));
    final recipesAsync = ref.watch(_recipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Groceries List (Lists tab)',
            onPressed: () async {
              final col = await ref
                  .read(groceriesServiceProvider)
                  .getOrCreateGroceriesCollection();
              if (context.mounted) {
                context.push('/collection/${col.id}');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Recipes',
            onPressed: () => context.push('/recipes'),
          ),
        ],
      ),
      body: Column(
        children: [
          _WeekHeader(
            weekStart: _weekStart,
            onPrev: _prevWeek,
            onNext: _nextWeek,
          ),
          Expanded(
            child: slotsAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (slotMap) {
                final recipes = recipesAsync.value ?? [];
                return _MealGrid(
                  weekStart: _weekStart,
                  slotMap: slotMap,
                  recipes: recipes,
                );
              },
            ),
          ),
          _BottomActions(week: _weekStart),
        ],
      ),
    );
  }
}

// ── Week Header ───────────────────────────────────────────────────────────────

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.weekStart,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM');
    final label = '${fmt.format(weekStart)} – ${fmt.format(end)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ── Grid ──────────────────────────────────────────────────────────────────────

class _MealGrid extends ConsumerWidget {
  const _MealGrid({
    required this.weekStart,
    required this.slotMap,
    required this.recipes,
  });

  final DateTime weekStart;
  final Map<String, Map<String, MealSlot>> slotMap;
  final List<Recipe> recipes;

  static const _slots = ['breakfast', 'lunch', 'dinner', 'post-gym-shake'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = List.generate(
      7,
      (i) => _dateStr(weekStart.add(Duration(days: i))),
    );

    final today = _dateStr(DateTime.now());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(148),
          columnWidths: const {
            0: FixedColumnWidth(80),
          },
          children: [
            // Row 0: Column Headers (Meal Slots)
            TableRow(
              children: [
                const _Cell(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Day',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                _MealHeaderCell(icon: Icons.wb_sunny_outlined, label: 'Breakfast', color: Colors.amber.shade800),
                _MealHeaderCell(icon: Icons.lunch_dining, label: 'Lunch', color: Colors.orange.shade800),
                _MealHeaderCell(icon: Icons.dinner_dining, label: 'Dinner', color: Colors.deepOrange.shade800),
                _MealHeaderCell(icon: Icons.fitness_center, label: 'Shake / Snack', color: Colors.purple.shade700),
              ],
            ),
            // Rows 1-7: Days of the week (Rows = Days)
            ...dates.asMap().entries.map((e) {
              final dateStr = e.value;
              final dayDate = weekStart.add(Duration(days: e.key));
              final dayName = _dayLabels[e.key];
              final dayNum = dayDate.day.toString();
              final isToday = dateStr == today;

              return TableRow(
                children: [
                  // Row Header: Day (Leftmost column)
                  _Cell(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isToday ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isToday ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 12,
                              color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Meal Columns
                  ..._slots.map((slotStr) {
                    final mealSlot = slotMap[dateStr]?[slotStr];
                    return _MealCell(
                      date: dateStr,
                      slot: slotStr,
                      mealSlot: mealSlot,
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MealHeaderCell extends StatelessWidget {
  const _MealHeaderCell({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Cell(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(3), child: child);
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
        ? Colors.grey
        : _statusColor(mealSlot!.status);

    final recipeId = mealSlot?.recipeId;

    return GestureDetector(
      onTap: () => _showSlotActions(context, ref),
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mealSlot != null ? statusColor.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.25),
            width: mealSlot != null ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: recipeId != null
            ? _RecipeCardContent(
                recipeId: recipeId,
                status: mealSlot!.status,
                statusColor: statusColor,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+ Add Meal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showSlotActions(BuildContext context, WidgetRef ref) {
    final slotRepo = ref.read(mealSlotRepositoryProvider);
    final recipeRepo = ref.read(recipeRepositoryProvider);
    final groceriesService = ref.read(groceriesServiceProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${slot.toUpperCase()} · $date',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: Text(mealSlot?.recipeId != null ? 'Change Recipe' : 'Assign Recipe'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final recipes = await recipeRepo.getAll();
                  if (!context.mounted) return;

                  showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetCtx) => ListView.builder(
                      itemCount: recipes.length,
                      itemBuilder: (_, i) {
                        final r = recipes[i];
                        return ListTile(
                          title: Text(r.name),
                          subtitle: Text(r.mealSlot.toUpperCase()),
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await slotRepo.upsert(
                              date: date,
                              slot: slot,
                              recipeId: r.id,
                              status: 'accepted',
                            );

                            final missing = await groceriesService.getMissingIngredientsForRecipe(r.id);
                            if (missing.isNotEmpty) {
                              await groceriesService.ensureMissingIngredientsInGroceriesList(missing);
                              if (context.mounted) {
                                final missingNames = missing.join(', ');
                                final col = await groceriesService.getOrCreateGroceriesCollection();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Planned "${r.name}"! 🛒 Need to buy: $missingNames'),
                                    action: SnackBarAction(
                                      label: 'Groceries List',
                                      onPressed: () => context.push('/collection/${col.id}'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              ),
              if (mealSlot?.recipeId != null)
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined, color: Colors.orange),
                  title: const Text('View Missing Ingredients'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final missing = await groceriesService.getMissingIngredientsForRecipe(mealSlot!.recipeId!);
                    if (context.mounted) {
                      _showMissingDialog(context, ref, mealSlot!.recipeId!, missing);
                    }
                  },
                ),
              if (mealSlot?.status == 'accepted' ||
                  mealSlot?.status == 'suggested') ...[
                ListTile(
                  leading: const Icon(Icons.check, color: Colors.green),
                  title: const Text('Mark eaten'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await slotRepo.updateStatus(date, slot, 'eaten');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.skip_next, color: Colors.grey),
                  title: const Text('Mark skipped'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await slotRepo.updateStatus(date, slot, 'skipped');
                  },
                ),
              ],
              if (mealSlot != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Clear slot'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await slotRepo.delete(date, slot);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMissingDialog(BuildContext context, WidgetRef ref, int recipeId, List<String> missing) {
    final groceriesService = ref.read(groceriesServiceProvider);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Missing Ingredients'),
        content: missing.isEmpty
            ? const Text('All ingredients for this meal are checked off in your Groceries List! 🎉')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: missing
                      .map(
                        (name) => ListTile(
                          leading: const Icon(Icons.remove_shopping_cart, color: Colors.orange),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              await groceriesService.toggleGroceryItemStock(name, true);
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            },
                            child: const Text('I Have It'),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final col = await groceriesService.getOrCreateGroceriesCollection();
              if (context.mounted) {
                context.push('/collection/${col.id}');
              }
            },
            child: const Text('Go to Groceries List'),
          ),
        ],
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

class _RecipeCardContent extends ConsumerWidget {
  const _RecipeCardContent({
    required this.recipeId,
    required this.status,
    required this.statusColor,
  });

  final int recipeId;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(_recipeObjectProvider(recipeId));
    final missingAsync = ref.watch(_missingIngredientsProvider(recipeId));
    final missingNames = missingAsync.value ?? [];

    return recipeAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Center(child: Text('?')),
      data: (recipe) {
        if (recipe == null) return const Center(child: Text('Unknown'));

        final imgProvider = imageProviderFor(recipe.image);

        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Recipe Image Thumbnail or Fallback Icon Header
              Expanded(
                flex: 5,
                child: Container(
                  color: statusColor.withValues(alpha: 0.15),
                  child: imgProvider != null
                      ? Image(
                          image: imgProvider,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _defaultBannerIcon(),
                        )
                      : _defaultBannerIcon(),
                ),
              ),
              // Recipe Name & Details
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (missingNames.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🛒 Need ${missingNames.length}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _defaultBannerIcon() {
    return Center(
      child: Icon(
        Icons.restaurant_menu,
        size: 20,
        color: statusColor,
      ),
    );
  }
}

final _recipeObjectProvider = FutureProvider.autoDispose.family<Recipe?, int>((
  ref,
  id,
) async {
  return ref.watch(recipeRepositoryProvider).getById(id);
});

final _recipeNameProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  id,
) async {
  final r = await ref.watch(recipeRepositoryProvider).getById(id);
  return r?.name;
});

final _missingIngredientsProvider =
    FutureProvider.autoDispose.family<List<String>, int>((ref, recipeId) async {
  return ref
      .watch(groceriesServiceProvider)
      .getMissingIngredientsForRecipe(recipeId);
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
    final profile = await ref.read(nutritionProfileRepositoryProvider).loadProfile();

    // 1. Verify generic setup profile is complete (managed in Fitness Tracker tab)
    if (!profile.isComplete) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please complete your Body Profile (Age, Height, Gender) in Fitness Tracker first.'),
            action: SnackBarAction(
              label: 'Fitness Tracker',
              onPressed: () => context.push('/fitness'),
            ),
          ),
        );
      }
      return;
    }

    // 2. Pre-generation confirmation dialog
    if (context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Next Week Setup'),
          content: const Text(
            'Please make sure you have updated sport activity plan, travel plan and partner plan for next week so you get the best result.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed & Generate'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final recipeRepo = ref.read(recipeRepositoryProvider);
    final dayRepo = ref.read(dayRepositoryProvider);
    final slotRepo = ref.read(mealSlotRepositoryProvider);
    final groceriesService = ref.read(groceriesServiceProvider);

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

    final allMissing = <String>{};
    for (final entry in suggestions.entries) {
      for (final slotEntry in entry.value.entries) {
        if (!slotEntry.value.noMatch && slotEntry.value.recipe != null) {
          await slotRepo.upsert(
            date: entry.key,
            slot: slotEntry.key,
            recipeId: slotEntry.value.recipe!.id,
            status: 'suggested',
          );
          final missing = await groceriesService
              .getMissingIngredientsForRecipe(slotEntry.value.recipe!.id);
          allMissing.addAll(missing);
        }
      }
    }

    if (allMissing.isNotEmpty) {
      await groceriesService.ensureMissingIngredientsInGroceriesList(
        allMissing.toList(),
      );
    }

    if (context.mounted) {
      if (allMissing.isNotEmpty) {
        final col = await groceriesService.getOrCreateGroceriesCollection();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Week suggested! 🛒 Added missing ingredients to Groceries list: ${allMissing.take(3).join(", ")}${allMissing.length > 3 ? "..." : ""}',
            ),
            action: SnackBarAction(
              label: 'Groceries List',
              onPressed: () => context.push('/collection/${col.id}'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Week suggestions generated! All ingredients in stock 🎉'),
          ),
        );
      }
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
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _weekSlotsProvider = StreamProvider.autoDispose
    .family<Map<String, Map<String, MealSlot>>, DateTime>((ref, week) {
  final repo = ref.watch(mealSlotRepositoryProvider);
  return repo.watchWeek(week).map((slots) {
    final map = <String, Map<String, MealSlot>>{};
    for (final s in slots) {
      (map[s.date] ??= {})[s.slot] = s;
    }
    return map;
  });
});

final _recipesProvider = StreamProvider.autoDispose<List<Recipe>>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watchAll();
});

// ── Recipes sub-screen ────────────────────────────────────────────────────────

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(_allRecipesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Groceries List (Lists tab)',
            onPressed: () async {
              final col = await ref
                  .read(groceriesServiceProvider)
                  .getOrCreateGroceriesCollection();
              if (context.mounted) {
                context.push('/collection/${col.id}');
              }
            },
          ),
        ],
      ),
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
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = recipes[i];
              final hasImage = hasDisplayableImage(r.image);
              final calStr = r.calories != null ? '🔥 ${r.calories} kcal  ' : '';
              final proteinStr =
                  r.proteinGrams != null ? '🥩 ${r.proteinGrams}g protein  ' : '';
              final tagsStr =
                  r.tags.isNotEmpty ? '· ${r.tags.take(3).join(', ')}' : '';

              return AppCard(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: DesignTokens.lineLight.withValues(alpha: 0.3),
                      child: hasImage
                          ? Image(image: imageProviderFor(r.image)!, fit: BoxFit.cover)
                          : const Icon(
                              Icons.restaurant_menu,
                              color: DesignTokens.peach,
                            ),
                    ),
                  ),
                  title: Text(
                    r.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${r.mealSlot.toUpperCase()}  $calStr$proteinStr$tagsStr',
                    style: const TextStyle(fontSize: 12),
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
  final clean = DateTime(d.year, d.month, d.day);
  return clean.subtract(Duration(days: clean.weekday - 1));
}

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
