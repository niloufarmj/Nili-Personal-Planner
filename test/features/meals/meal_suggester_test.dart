import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/meals/meal_suggester.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Recipe _recipe({
  required int id,
  required String name,
  String slot = 'dinner',
  List<String> tags = const [],
}) => Recipe(
  id: id,
  name: name,
  mealSlot: slot,
  prepMinutes: null,
  tags: tags,
  instructions: null,
  image: null,
);

MealSlot _histSlot(int recipeId, String date) => MealSlot(
  date: date,
  slot: 'dinner',
  recipeId: recipeId,
  status: 'accepted',
);

DayContext _day(String date, {List<String> tags = const []}) =>
    DayContext(date: date, tagNames: tags);

List<DayContext> _plainWeek() => [
  _day('2026-06-08'),
  _day('2026-06-09'),
  _day('2026-06-10'),
  _day('2026-06-11'),
  _day('2026-06-12'),
  _day('2026-06-13'),
  _day('2026-06-14'),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  final seeded = Random(42);
  MealSuggester mkSuggester() => MealSuggester(random: seeded);

  // ── Travel days ──────────────────────────────────────────────────────────────

  test('travel days produce empty slot map', () {
    final week = [
      _day('2026-06-08', tags: ['travel']),
      ..._plainWeek().skip(1),
    ];
    final result = mkSuggester().suggest(
      week: week,
      pool: [_recipe(id: 1, name: 'Schnitzel')],
      recentHistory: [],
    );
    expect(result['2026-06-08'], isEmpty);
  });

  // ── Hard constraint: gym day → high-protein dinner ────────────────────────────

  test('gym day dinner picks high-protein recipe when available', () {
    final week = [
      _day('2026-06-08', tags: ['gym']),
      ..._plainWeek().skip(1),
    ];
    final pool = [
      _recipe(id: 1, name: 'Steak', slot: 'dinner', tags: ['high-protein']),
      _recipe(id: 2, name: 'Pasta', slot: 'dinner'),
    ];
    final result = mkSuggester().suggest(
      week: week,
      pool: pool,
      recentHistory: [],
    );
    final dinner = result['2026-06-08']!['dinner'];
    expect(dinner?.noMatch, isFalse);
    expect(dinner?.recipe?.tags, contains('high-protein'));
  });

  test('gym day dinner returns noMatch when no high-protein recipe exists', () {
    final week = [
      _day('2026-06-08', tags: ['gym']),
      ..._plainWeek().skip(1),
    ];
    final pool = [_recipe(id: 1, name: 'Pasta', slot: 'dinner')];
    final result = mkSuggester().suggest(
      week: week,
      pool: pool,
      recentHistory: [],
    );
    expect(result['2026-06-08']!['dinner']?.noMatch, isTrue);
  });

  // ── Pref constraint: work day lunch → prep-ahead / quick ──────────────────────

  test('work day lunch prefers prep-ahead recipe', () {
    final week = [
      _day('2026-06-08', tags: ['work']),
      ..._plainWeek().skip(1),
    ];
    final pool = [
      _recipe(id: 1, name: 'Meal prep', slot: 'lunch', tags: ['prep-ahead']),
      _recipe(id: 2, name: 'Random', slot: 'lunch'),
    ];
    final result = mkSuggester().suggest(
      week: week,
      pool: pool,
      recentHistory: [],
    );
    final lunch = result['2026-06-08']!['lunch'];
    expect(lunch?.noMatch, isFalse);
    expect(lunch?.recipe?.tags, contains('prep-ahead'));
  });

  test('work day lunch falls back to any lunch when no pref match', () {
    final week = [
      _day('2026-06-08', tags: ['work']),
      ..._plainWeek().skip(1),
    ];
    final pool = [_recipe(id: 1, name: 'Any lunch', slot: 'lunch')];
    final result = mkSuggester().suggest(
      week: week,
      pool: pool,
      recentHistory: [],
    );
    final lunch = result['2026-06-08']!['lunch'];
    expect(lunch?.noMatch, isFalse);
    expect(lunch?.recipe?.name, 'Any lunch');
  });

  // ── Pref constraint: reza/linz day → reza-shared ─────────────────────────────

  test('reza-day prefers reza-shared recipe', () {
    final week = [
      _day('2026-06-08', tags: ['reza-day']),
      ..._plainWeek().skip(1),
    ];
    final pool = [
      _recipe(
        id: 1,
        name: 'Shared pasta',
        slot: 'dinner',
        tags: ['reza-shared'],
      ),
      _recipe(id: 2, name: 'Solo steak', slot: 'dinner'),
    ];
    final result = mkSuggester().suggest(
      week: week,
      pool: pool,
      recentHistory: [],
    );
    final dinner = result['2026-06-08']!['dinner'];
    expect(dinner?.recipe?.tags, contains('reza-shared'));
  });

  // ── Gym day: post-gym-shake slot added ────────────────────────────────────────

  test('gym day includes post-gym-shake slot', () {
    final week = [
      _day('2026-06-08', tags: ['gym']),
      ..._plainWeek().skip(1),
    ];
    final pool = [
      _recipe(id: 1, name: 'Shake', slot: 'post-gym-shake'),
      _recipe(id: 2, name: 'Steak', slot: 'dinner', tags: ['high-protein']),
      _recipe(id: 3, name: 'Oats', slot: 'breakfast'),
      _recipe(id: 4, name: 'Wrap', slot: 'lunch'),
    ];
    final result = mkSuggester().suggest(
      week: week,
      pool: pool,
      recentHistory: [],
    );
    expect(result['2026-06-08']!.containsKey('post-gym-shake'), isTrue);
    expect(result['2026-06-09']!.containsKey('post-gym-shake'), isFalse);
  });

  // ── Empty pool → noMatch ─────────────────────────────────────────────────────

  test('empty pool produces noMatch for all slots', () {
    final result = mkSuggester().suggest(
      week: _plainWeek(),
      pool: [],
      recentHistory: [],
    );
    for (final day in result.values) {
      for (final suggestion in day.values) {
        expect(suggestion.noMatch, isTrue);
      }
    }
  });

  // ── No-repeat: history excludes recipes ───────────────────────────────────────

  test('history recipes are excluded from suggestions', () {
    final r1 = _recipe(id: 1, name: 'Pasta', slot: 'dinner');
    final r2 = _recipe(id: 2, name: 'Risotto', slot: 'dinner');
    final history = [_histSlot(r1.id, '2026-06-01')]; // prev week

    final result = mkSuggester().suggest(
      week: _plainWeek(),
      pool: [r1, r2],
      recentHistory: history,
    );
    // r1 should not appear in the first day (within no-repeat window)
    final mon = result['2026-06-08']!['dinner'];
    expect(mon?.recipe?.id, isNot(r1.id));
  });

  // ── No-repeat within week ────────────────────────────────────────────────────

  test('same recipe not repeated within 3-day window', () {
    final recipes = List.generate(
      10,
      (i) => _recipe(id: i + 1, name: 'Recipe ${i + 1}', slot: 'dinner'),
    );
    final result = MealSuggester(
      random: Random(0),
    ).suggest(week: _plainWeek(), pool: recipes, recentHistory: []);
    final dinnerIds = _plainWeek()
        .map((d) => result[d.date]?['dinner']?.recipe?.id)
        .whereType<int>()
        .toList();

    // Check no id appears within 3-day windows
    for (var i = 0; i < dinnerIds.length; i++) {
      for (var j = i + 1; j < dinnerIds.length && j <= i + 3; j++) {
        expect(
          dinnerIds[i],
          isNot(equals(dinnerIds[j])),
          reason: 'Recipe ${dinnerIds[i]} repeated at days $i and $j',
        );
      }
    }
  });

  // ── Determinism ─────────────────────────────────────────────────────────────

  test('same Random seed produces same output', () {
    final pool = List.generate(
      5,
      (i) => _recipe(id: i + 1, name: 'Recipe $i', slot: 'dinner'),
    );
    final r1 = MealSuggester(
      random: Random(99),
    ).suggest(week: _plainWeek(), pool: pool, recentHistory: []);
    final r2 = MealSuggester(
      random: Random(99),
    ).suggest(week: _plainWeek(), pool: pool, recentHistory: []);
    for (final d in _plainWeek().map((d) => d.date)) {
      expect(
        r1[d]?['dinner']?.recipe?.id,
        equals(r2[d]?['dinner']?.recipe?.id),
        reason: 'Mismatch on $d',
      );
    }
  });

  // ── Combined tags ────────────────────────────────────────────────────────────

  test('combined gym+work day satisfies both hard and pref constraints', () {
    final week = [
      _day('2026-06-08', tags: ['gym', 'work']),
      ..._plainWeek().skip(1),
    ];
    final pool = [
      _recipe(
        id: 1,
        name: 'Prep steak',
        slot: 'dinner',
        tags: ['high-protein', 'prep-ahead'],
      ),
      _recipe(id: 2, name: 'Pasta', slot: 'dinner'),
      _recipe(id: 3, name: 'Prep wrap', slot: 'lunch', tags: ['prep-ahead']),
      _recipe(id: 4, name: 'Any lunch', slot: 'lunch'),
    ];
    final result = mkSuggester().suggest(
      week: week,
      pool: pool,
      recentHistory: [],
    );
    final dinner = result['2026-06-08']!['dinner'];
    expect(dinner?.recipe?.tags, contains('high-protein'));
    final lunch = result['2026-06-08']!['lunch'];
    expect(lunch?.recipe?.tags, contains('prep-ahead'));
  });
}
