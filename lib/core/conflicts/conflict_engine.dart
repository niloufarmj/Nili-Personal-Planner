import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import 'conflict_item.dart';
import 'rules/conflict_rule.dart';
import 'rules/travel_event_rule.dart';
import 'rules/travel_gym_rule.dart';
import 'rules/travel_meal_rule.dart';

/// Live implementation of [ConflictFeed].
///
/// Evaluates all registered rules for [date] and filters dismissed items.
/// Adding a rule ≈ adding one [ConflictRule] to [_rules].
class ConflictEngine implements ConflictFeed {
  ConflictEngine(this._db);

  final AppDatabase _db;

  static const List<ConflictRule> _rules = [
    TravelGymRule(),
    TravelEventRule(),
    TravelMealRule(),
  ];

  @override
  Stream<List<ConflictItem>> watchConflicts(DateTime date) async* {
    yield await _evaluate(date);

    // Re-evaluate whenever day_tags, gym_sessions, or meal_slots change.
    // Subscriptions are tracked so they can be cancelled when the generator
    // is disposed (prevents Drift stream leaks in long-lived containers).
    final subs = <StreamSubscription<dynamic>>[];
    final controller = StreamController<void>.broadcast();

    for (final stream in [
      _db.select(_db.dayTags).watch(),
      _db.select(_db.gymSessions).watch(),
      _db.select(_db.mealSlots).watch(),
    ]) {
      subs.add(
        stream.listen((_) {
          if (!controller.isClosed) controller.add(null);
        }),
      );
    }

    try {
      await for (final _ in controller.stream) {
        yield await _evaluate(date);
      }
    } finally {
      for (final sub in subs) {
        await sub.cancel();
      }
      if (!controller.isClosed) await controller.close();
    }
  }

  Future<List<ConflictItem>> _evaluate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final results = <ConflictItem>[];
    for (final rule in _rules) {
      final items = await rule.evaluate(_db, date);
      for (final item in items) {
        if (prefs.getBool('dismissed:${item.id}') != true) {
          results.add(item);
        }
      }
    }
    return results;
  }

  /// Persists a dismissal so the card never re-appears.
  static Future<void> dismiss(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissed:$id', true);
  }
}

final conflictFeedProvider = Provider<ConflictFeed>(
  (ref) => ConflictEngine(ref.watch(appDatabaseProvider)),
);
