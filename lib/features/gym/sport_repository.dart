import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

final sportRepositoryProvider = Provider<SportRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SportRepository(db);
});

final sportActivitiesProvider = StreamProvider.autoDispose<List<SportActivity>>((ref) {
  return ref.watch(sportRepositoryProvider).watchAllActivities();
});

class SportRepository {
  const SportRepository(this._db);
  final AppDatabase _db;

  Stream<List<SportActivity>> watchAllActivities() {
    return (_db.select(_db.sportActivities)
          ..orderBy([(s) => OrderingTerm.desc(s.date)]))
        .watch();
  }

  Future<List<SportActivity>> getActivitiesForRange(String startDate, String endDate) {
    return (_db.select(_db.sportActivities)
          ..where((s) => s.date.isBiggerOrEqualValue(startDate) & s.date.isSmallerOrEqualValue(endDate))
          ..orderBy([(s) => OrderingTerm.asc(s.date)]))
        .get();
  }

  Stream<List<SportActivity>> watchActivitiesForRange(String startDate, String endDate) {
    return (_db.select(_db.sportActivities)
          ..where((s) => s.date.isBiggerOrEqualValue(startDate) & s.date.isSmallerOrEqualValue(endDate))
          ..orderBy([(s) => OrderingTerm.asc(s.date)]))
        .watch();
  }

  Future<int> logActivity({
    required String date,
    required String activityType,
    required int durationMin,
    int? calories,
    String? intensity,
    String? notes,
    int? gymPlanId,
  }) {
    return _db.into(_db.sportActivities).insert(
          SportActivitiesCompanion.insert(
            date: date,
            activityType: activityType,
            durationMin: durationMin,
            calories: Value(calories),
            intensity: Value(intensity),
            notes: Value(notes),
            gymPlanId: Value(gymPlanId),
          ),
        );
  }

  Future<void> deleteActivity(int id) {
    return (_db.delete(_db.sportActivities)..where((s) => s.id.equals(id))).go();
  }
}
