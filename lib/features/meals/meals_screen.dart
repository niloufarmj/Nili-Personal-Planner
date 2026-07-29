import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';
import 'groceries_service.dart';
import 'meal_slot_repository.dart';
import 'meal_suggester.dart';
import 'recipe_repository.dart';
import 'shopping_generator.dart';

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

  /// dateStr -> (slotStr -> MealSlot)
  final Map<String, Map<String, MealSlot>> slotMap;
  final List<Recipe> recipes;

  static const _slots = ['breakfast', 'lunch', 'dinner', 'post-gym-shake'];

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = List.generate(
      7,
      (i) => _dateStr(weekStart.add(Duration(days: i))),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(88),
          children: [
            // Row 0: Day headers
            TableRow(
              children: [
                const _Cell(child: Text('Slot')),
                ...dates.asMap().entries.map((e) {
                  final dayNum = weekStart
                      .add(Duration(days: e.key))
                      .day
                      .toString();
                  return _Cell(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dayLabels[e.key],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            dayNum,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            // Rows 1-4: Slots
            ..._slots.map(
              (slotStr) => TableRow(
                children: [
                  _Cell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _slotLabel(slotStr),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  ...dates.map((dateStr) {
                    final mealSlot = slotMap[dateStr]?[slotStr];
                    return _MealCell(
                      date: dateStr,
                      slot: slotStr,
                      mealSlot: mealSlot,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _slotLabel(String s) => switch (s) {
    'breakfast' => 'Brkfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'post-gym-shake' => 'Shake',
    _ => s,
  };
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

class _RecipeName extends ConsumerWidget {
  const _RecipeName({required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(_recipeNameProvider(recipeId));
    final missingAsync = ref.watch(_missingIngredientsProvider(recipeId));
    final missingNames = missingAsync.value ?? [];

    return recipeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Text('?'),
      data: (name) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name ?? '?',
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (missingNames.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 10, color: Colors.redAccent),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'Need: ${missingNames.join(", ")}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
              final hasImage = r.image != null && File(r.image!).existsSync();
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
                          ? Image.file(File(r.image!), fit: BoxFit.cover)
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
                    '${r.mealSlot.toUpperCase()}  $proteinStr$tagsStr',
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
