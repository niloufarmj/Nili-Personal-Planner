import 'package:personal_planner/core/db/database.dart';

import '../conflict_item.dart';

/// Base class for conflict rules. Adding a rule = one subclass + tests.
abstract class ConflictRule {
  const ConflictRule();

  /// Evaluates the rule for [date] against [db]. Returns any triggered items.
  Future<List<ConflictItem>> evaluate(AppDatabase db, DateTime date);

  static String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
