import 'dart:math';

import '../../core/db/database.dart';

/// Day tags relevant to meal suggestions.
class DayContext {
  const DayContext({required this.date, required this.tagNames});

  final String date;
  final List<String> tagNames;

  bool get isGymDay => tagNames.contains('gym');
  bool get isWorkDay => tagNames.contains('work');
  bool get isPartnerDay => tagNames.contains('partner-day');
  bool get isLinzDay => tagNames.contains('linz');
  bool get isTravelDay => tagNames.contains('travel');
  bool get isPeriodDay => tagNames.contains('period');
}

/// Result for one meal slot — either a recipe or a "no match" signal.
class SlotSuggestion {
  const SlotSuggestion.recipe(this.recipe) : noMatch = false;
  const SlotSuggestion.noMatch() : recipe = null, noMatch = true;

  final Recipe? recipe;
  final bool noMatch;
}

/// Pure, deterministic meal suggester.
///
/// Input: 7 [DayContext]s + recipe pool + recent meal history (tail of previous
/// week). All randomness is injectable via [random] for deterministic tests.
///
/// Constraint levels:
///   Hard   – can never be violated; produces noMatch when unsatisfiable.
///   Pref   – relaxed first when no hard-constraint recipe is available.
class MealSuggester {
  const MealSuggester({Random? random}) : _random = random;

  final Random? _random;

  static const _noRepeatDays = 3;

  /// Generates suggestions for all 7 days × all applicable slots.
  ///
  /// Returns a map keyed by date → slot → [SlotSuggestion].
  Map<String, Map<String, SlotSuggestion>> suggest({
    required List<DayContext> week,
    required List<Recipe> pool,
    required List<MealSlot> recentHistory, // previous-week accepted slots
  }) {
    assert(week.length == 7, 'week must have exactly 7 days');

    final usedIds =
        <String, Set<int>>{}; // date → set of recipe ids used so far this week
    final historyIds = recentHistory
        .map((s) => s.recipeId)
        .whereType<int>()
        .toSet();

    final result = <String, Map<String, SlotSuggestion>>{};

    for (final day in week) {
      if (day.isTravelDay) {
        result[day.date] = {}; // travel days get no suggestions
        continue;
      }

      final slots = _slotsForDay(day);
      result[day.date] = {};

      for (final slot in slots) {
        final usedThisWeek = _recentIds(
          day.date,
          week.map((d) => d.date).toList(),
          usedIds,
        );
        final excluded = {...historyIds, ...usedThisWeek};

        final suggestion = _pickForSlot(
          slot: slot,
          day: day,
          pool: pool,
          excluded: excluded,
        );

        result[day.date]![slot] = suggestion;

        if (!suggestion.noMatch && suggestion.recipe != null) {
          (usedIds[day.date] ??= {}).add(suggestion.recipe!.id);
        }
      }
    }

    return result;
  }

  // ── Slot list ────────────────────────────────────────────────────

  List<String> _slotsForDay(DayContext day) {
    return ['breakfast', 'lunch', 'dinner', if (day.isGymDay) 'post-gym-shake'];
  }

  // ── Constraint application ───────────────────────────────────────

  SlotSuggestion _pickForSlot({
    required String slot,
    required DayContext day,
    required List<Recipe> pool,
    required Set<int> excluded,
  }) {
    // Pool for this slot (exact slot or 'any').
    final slotPool = pool
        .where((r) => r.mealSlot == slot || r.mealSlot == 'any')
        .where((r) => !excluded.contains(r.id))
        .toList();

    if (slotPool.isEmpty) return const SlotSuggestion.noMatch();

    // Build hard constraints for the slot.
    final hardTags = _hardTags(slot, day);
    // Build preference constraints.
    final prefTags = _prefTags(slot, day);

    // Try: hard + pref.
    var candidates = _filterByTags(slotPool, [...hardTags, ...prefTags]);
    if (candidates.isNotEmpty) {
      return SlotSuggestion.recipe(_pick(candidates, slot: slot, day: day));
    }

    // Relax preferences: hard only.
    candidates = _filterByTags(slotPool, hardTags);
    if (candidates.isNotEmpty) {
      return SlotSuggestion.recipe(_pick(candidates, slot: slot, day: day));
    }

    // Hard constraints not satisfiable → noMatch.
    if (hardTags.isNotEmpty) return const SlotSuggestion.noMatch();

    // No hard constraints → pick from full slot pool.
    return SlotSuggestion.recipe(_pick(slotPool, slot: slot, day: day));
  }

  List<String> _hardTags(String slot, DayContext day) {
    final tags = <String>[];
    if (slot == 'dinner' && day.isGymDay) tags.add('high-protein');
    return tags;
  }

  List<String> _prefTags(String slot, DayContext day) {
    final tags = <String>[];
    final dateObj = DateTime.tryParse(day.date);
    final isWeekend = dateObj != null &&
        (dateObj.weekday == DateTime.saturday ||
            dateObj.weekday == DateTime.sunday);

    if (slot == 'lunch') {
      if (day.isWorkDay || !isWeekend) {
        tags.addAll(['prep-ahead', 'meal-prep', 'quick', 'pasta', 'bento']);
      } else if (isWeekend) {
        tags.addAll(['special', 'persian', 'weekend', 'fresh']);
      }
    } else if (slot == 'dinner') {
      if (isWeekend) {
        tags.addAll(['special', 'favorite', 'baked', 'persian', 'weekend']);
      } else {
        tags.addAll(['soup', 'salad', 'light', '30%veggies', 'steamed']);
      }
    }

    if (day.isPartnerDay || day.isLinzDay) {
      tags.add('partner-shared');
    }
    return tags;
  }

  List<Recipe> _filterByTags(List<Recipe> pool, List<String> required) {
    if (required.isEmpty) return pool;
    return pool.where((r) => required.any((t) => r.tags.contains(t))).toList();
  }

  Recipe _pick(List<Recipe> candidates, {String? slot, DayContext? day}) {
    if (candidates.length == 1) return candidates.first;
    if (slot == null || day == null) {
      final rng = _random ?? Random();
      return candidates[rng.nextInt(candidates.length)];
    }

    final scored = candidates.map((recipe) {
      double score = 10.0;
      final tags = recipe.tags.map((t) => t.toLowerCase()).toList();
      final name = recipe.name.toLowerCase();
      final calories = recipe.calories ?? 450;
      final protein = recipe.proteinGrams ?? 25;

      // 1. Gym day high-protein & calories vs Rest day moderate balance
      if (day.isGymDay) {
        if (protein >= 30) score += 15.0;
        if (calories >= 450) score += 10.0;
      } else {
        if (calories <= 550) score += 8.0;
      }

      // 2. Workday meal-prep context vs Weekend cooking context
      final dateObj = DateTime.tryParse(day.date);
      final isWeekend = dateObj != null &&
          (dateObj.weekday == DateTime.saturday ||
              dateObj.weekday == DateTime.sunday);

      if (slot == 'lunch') {
        if (day.isWorkDay || !isWeekend) {
          if (tags.contains('prep-ahead') ||
              tags.contains('meal-prep') ||
              tags.contains('pasta') ||
              name.contains('rice') ||
              name.contains('bento') ||
              name.contains('pesto')) {
            score += 15.0;
          }
        }
      } else if (slot == 'dinner') {
        if (isWeekend) {
          if (tags.contains('special') ||
              tags.contains('favorite') ||
              tags.contains('baked') ||
              name.contains('lasagna') ||
              name.contains('zereshk')) {
            score += 20.0;
          }
        } else {
          if (tags.contains('soup') ||
              tags.contains('salad') ||
              tags.contains('light') ||
              tags.contains('30%veggies') ||
              name.contains('salad') ||
              name.contains('soup') ||
              name.contains('broccoli')) {
            score += 15.0;
          }
        }
      }

      // 3. Exact slot matching
      if (recipe.mealSlot == slot) {
        score += 8.0;
      }

      return MapEntry(recipe, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    final maxScore = scored.first.value;
    final topCandidates = scored
        .where((e) => (maxScore - e.value) < 3.0)
        .map((e) => e.key)
        .toList();

    final rng = _random ?? Random();
    return topCandidates[rng.nextInt(topCandidates.length)];
  }

  // ── No-repeat window ─────────────────────────────────────────────

  /// Returns recipe ids used within [_noRepeatDays] before [date] this week.
  Set<int> _recentIds(
    String date,
    List<String> weekDates,
    Map<String, Set<int>> usedIds,
  ) {
    final idx = weekDates.indexOf(date);
    final result = <int>{};
    for (var i = 1; i <= _noRepeatDays && idx - i >= 0; i++) {
      result.addAll(usedIds[weekDates[idx - i]] ?? {});
    }
    return result;
  }
}
