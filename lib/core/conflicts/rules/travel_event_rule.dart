import 'package:drift/drift.dart';
import 'package:personal_planner/core/db/database.dart';

import '../conflict_item.dart';
import 'conflict_rule.dart';

/// R2: final trip overlapping an event owned by 'me' → informational flag.
class TravelEventRule extends ConflictRule {
  const TravelEventRule();

  @override
  Future<List<ConflictItem>> evaluate(AppDatabase db, DateTime date) async {
    final dateStr = ConflictRule.fmt(date);

    // Is today within any final trip?
    final finalTrips = await (db.select(
      db.trips,
    )..where((t) => t.status.equals('final'))).get();

    final overlapping = finalTrips.where((t) {
      if (t.startDate == null || t.endDate == null) return false;
      return dateStr.compareTo(t.startDate!) >= 0 &&
          dateStr.compareTo(t.endDate!) <= 0;
    }).toList();

    if (overlapping.isEmpty) return [];

    // Are there 'me' events on this date?
    final events = await (db.select(
      db.events,
    )..where((e) => e.date.equals(dateStr) & e.owner.equals('me'))).get();

    if (events.isEmpty) return [];

    return events.map((e) {
      final tripTitle = overlapping.first.title;
      return ConflictItem(
        id: 'R2:$dateStr:${e.id}',
        message: 'Trip "$tripTitle" overlaps your event "${e.title}".',
        severity: ConflictSeverity.info,
      );
    }).toList();
  }
}
