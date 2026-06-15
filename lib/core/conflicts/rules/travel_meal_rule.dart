import 'package:drift/drift.dart';
import 'package:personal_planner/core/db/database.dart';

import '../conflict_item.dart';
import 'conflict_rule.dart';

/// R3: 'travel' tag on a date with accepted meal_slots →
/// suggest clearing those slots.
class TravelMealRule extends ConflictRule {
  const TravelMealRule();

  @override
  Future<List<ConflictItem>> evaluate(AppDatabase db, DateTime date) async {
    final dateStr = ConflictRule.fmt(date);

    // Check for travel tag.
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

    // Check for accepted meal slots.
    final slots =
        await (db.select(db.mealSlots)..where(
              (s) =>
                  s.date.equals(dateStr) &
                  (s.status.equals('accepted') | s.status.equals('suggested')),
            ))
            .get();
    if (slots.isEmpty) return [];

    return [
      ConflictItem(
        id: 'R3:$dateStr',
        message:
            'You have ${slots.length} meal slot(s) planned on a travel day ($dateStr).',
        severity: ConflictSeverity.warning,
        actions: [
          ConflictAction(
            label: 'Clear meal slots',
            onTap: () => _clearSlots(db, dateStr),
          ),
        ],
      ),
    ];
  }

  Future<void> _clearSlots(AppDatabase db, String dateStr) async {
    await (db.delete(db.mealSlots)..where((s) => s.date.equals(dateStr))).go();
  }
}
