import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rrule/rrule.dart';

import '../../../core/db/database.dart';

/// Handles chore completion: logs history, advances due_date via RRULE,
/// and resets status to open.
class ChoreService {
  const ChoreService(this._db);

  final AppDatabase _db;

  static final _dateFmt = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Completes a chore occurrence:
  /// 1. Writes a row to chore_completions.
  /// 2. Advances due_date to the next RRULE occurrence.
  /// 3. Resets status to 'open' and clears done_date.
  Future<void> completeChore(int itemId, {String openStatus = 'open'}) async {
    final item = await (_db.select(
      _db.items,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (item == null) return;

    final today = _todayIso();

    // Log the completion.
    await _db
        .into(_db.choreCompletions)
        .insert(
          ChoreCompletionsCompanion.insert(
            itemId: itemId,
            completedAt: today,
            dueDateAtCompletion: Value(item.dueDate),
          ),
        );

    // Advance due_date to the next occurrence.
    final nextDue = _nextOccurrence(item.recurrence, item.dueDate ?? today);

    // Reset the item to open.
    await (_db.update(_db.items)..where((i) => i.id.equals(itemId))).write(
      ItemsCompanion(
        status: Value(openStatus),
        doneDate: const Value(null),
        dueDate: Value(nextDue),
      ),
    );
  }

  /// Returns completion history for [itemId], most recent first.
  Future<List<ChoreCompletion>> getCompletions(int itemId) =>
      (_db.select(_db.choreCompletions)
            ..where((c) => c.itemId.equals(itemId))
            ..orderBy([(c) => OrderingTerm.desc(c.completedAt)]))
          .get();

  /// True when the item has a past due_date and is not in the done status.
  static bool isOverdue(
    Item item, {
    String doneStatus = 'done',
    DateTime? now,
  }) {
    if (item.dueDate == null) return false;
    if (!_dateFmt.hasMatch(item.dueDate!)) return false;
    if (item.status == doneStatus) return false;
    final due = DateTime.parse(item.dueDate!);
    final today = now ?? DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    return due.isBefore(todayDay);
  }

  /// Computes the next RRULE occurrence after [fromIso].
  /// Returns null when there is no recurrence or parsing fails.
  static String? _nextOccurrence(String? rruleStr, String fromIso) {
    if (rruleStr == null || rruleStr.isEmpty) return null;
    try {
      final ruleStr = rruleStr.startsWith('RRULE:')
          ? rruleStr
          : 'RRULE:$rruleStr';
      final rule = RecurrenceRule.fromString(ruleStr);
      final from = DateTime.parse(fromIso);
      // Pass [from] as DTSTART so the rule's interval anchors to the correct
      // day-of-week / day-of-month. getInstances returns [from] itself as the
      // first element; skip it to advance by exactly one interval.
      final fromUtc = DateTime.utc(from.year, from.month, from.day);
      final next = rule.getInstances(start: fromUtc).skip(1).first;
      return '${next.year.toString().padLeft(4, '0')}-'
          '${next.month.toString().padLeft(2, '0')}-'
          '${next.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  static String _todayIso() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

final choreServiceProvider = Provider<ChoreService>(
  (ref) => ChoreService(ref.watch(appDatabaseProvider)),
);
