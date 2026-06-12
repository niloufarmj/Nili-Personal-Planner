import 'package:drift/drift.dart';
import 'package:personal_planner/core/db/database.dart';

import '../conflict_item.dart';
import 'conflict_rule.dart';

/// R1: 'travel' tag on a day with a planned gym_session →
/// suggest "move or skip session".
class TravelGymRule extends ConflictRule {
  const TravelGymRule();

  @override
  Future<List<ConflictItem>> evaluate(AppDatabase db, DateTime date) async {
    final dateStr = ConflictRule.fmt(date);

    // Check for travel tag on this date.
    final travelTags = await (db.select(
      db.tags,
    )..where((t) => t.name.equals('travel'))).get();
    if (travelTags.isEmpty) return [];
    final travelTagId = travelTags.first.id;

    final dayTagRows =
        await (db.select(db.dayTags)..where(
              (dt) => dt.date.equals(dateStr) & dt.tagId.equals(travelTagId),
            ))
            .get();
    if (dayTagRows.isEmpty) return [];

    // Check for a planned gym session on the same date.
    final sessions = await (db.select(
      db.gymSessions,
    )..where((s) => s.date.equals(dateStr) & s.status.equals('planned'))).get();
    if (sessions.isEmpty) return [];

    final session = sessions.first;
    final id = 'R1:$dateStr:${session.id}';

    return [
      ConflictItem(
        id: id,
        message:
            'You\'re travelling on $dateStr but have a planned gym session.',
        severity: ConflictSeverity.warning,
        actions: [
          ConflictAction(
            label: 'Skip session',
            onTap: () => _skipSession(db, session.id),
          ),
          ConflictAction(
            label: 'Move to next free day',
            onTap: () => _moveSession(db, session, date),
          ),
        ],
      ),
    ];
  }

  Future<void> _skipSession(AppDatabase db, int sessionId) async {
    await (db.update(db.gymSessions)..where((s) => s.id.equals(sessionId)))
        .write(const GymSessionsCompanion(status: Value('missed')));
  }

  Future<void> _moveSession(
    AppDatabase db,
    GymSession session,
    DateTime travelDate,
  ) async {
    // Find the next non-travel day within 14 days.
    final travelTags = await (db.select(
      db.tags,
    )..where((t) => t.name.equals('travel'))).get();
    if (travelTags.isEmpty) return;
    final travelTagId = travelTags.first.id;

    DateTime candidate = travelDate.add(const Duration(days: 1));
    for (var i = 0; i < 14; i++) {
      final candidateStr = ConflictRule.fmt(candidate);
      final rows =
          await (db.select(db.dayTags)..where(
                (dt) =>
                    dt.date.equals(candidateStr) & dt.tagId.equals(travelTagId),
              ))
              .get();
      if (rows.isEmpty) {
        // Move session to this date.
        await (db.update(db.gymSessions)..where((s) => s.id.equals(session.id)))
            .write(GymSessionsCompanion(date: Value(candidateStr)));
        return;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
  }
}
