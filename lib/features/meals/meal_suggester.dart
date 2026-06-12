import 'dart:math';

import '../../core/db/database.dart';

/// Day tags relevant to meal suggestions.
class DayContext {
  const DayContext({required this.date, required this.tagNames});

  final String date;
  final List<String> tagNames;

  bool get isGymDay => tagNames.contains('gym');
  bool get isWorkDay => tagNames.contains('work');
  bool get isRezaDay => tagNames.contains('reza-day');
  bool get isLinzDay => tagNames.contains('linz');
  bool get isTravelDay => tagNames.contains('travel');
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
    if (candidates.isNotEmpty) return SlotSuggestion.recipe(_pick(candidates));

    // Relax preferences: hard only.
    candidates = _filterByTags(slotPool, hardTags);
    if (candidates.isNotEmpty) return SlotSuggestion.recipe(_pick(candidates));

    // Hard constraints not satisfiable → noMatch.
    if (hardTags.isNotEmpty) return const SlotSuggestion.noMatch();

    // No hard constraints → pick from full slot pool.
    return SlotSuggestion.recipe(_pick(slotPool));
  }

  List<String> _hardTags(String slot, DayContext day) {
    final tags = <String>[];
    if (slot == 'dinner' && day.isGymDay) tags.add('high-protein');
    return tags;
  }

  List<String> _prefTags(String slot, DayContext day) {
    final tags = <String>[];
    if (slot == 'lunch' && day.isWorkDay) tags.addAll(['prep-ahead', 'quick']);
    if (day.isRezaDay || day.isLinzDay) tags.add('reza-shared');
    return tags;
  }

  List<Recipe> _filterByTags(List<Recipe> pool, List<String> required) {
    if (required.isEmpty) return pool;
    return pool.where((r) => required.any((t) => r.tags.contains(t))).toList();
  }

  Recipe _pick(List<Recipe> candidates) {
    final rng = _random ?? Random();
    return candidates[rng.nextInt(candidates.length)];
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
