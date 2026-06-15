import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

class MealSlotRepository {
  MealSlotRepository(this._db);

  final AppDatabase _db;

  Stream<List<MealSlot>> watchWeek(DateTime weekStart) {
    final dates = List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      return _fmt(d);
    });
    return (_db.select(
      _db.mealSlots,
    )..where((s) => s.date.isIn(dates))).watch();
  }

  Future<List<MealSlot>> getForDate(String date) =>
      (_db.select(_db.mealSlots)..where((s) => s.date.equals(date))).get();

  Future<List<MealSlot>> getForWeek(DateTime weekStart) {
    final dates = List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      return _fmt(d);
    });
    return (_db.select(_db.mealSlots)..where((s) => s.date.isIn(dates))).get();
  }

  /// Upserts a meal slot (idempotent).
  Future<void> upsert({
    required String date,
    required String slot,
    int? recipeId,
    required String status,
  }) => _db
      .into(_db.mealSlots)
      .insertOnConflictUpdate(
        MealSlotsCompanion.insert(
          date: date,
          slot: slot,
          recipeId: Value(recipeId),
          status: status,
        ),
      );

  Future<void> updateStatus(String date, String slot, String status) async {
    await (_db.update(_db.mealSlots)
          ..where((s) => s.date.equals(date) & s.slot.equals(slot)))
        .write(MealSlotsCompanion(status: Value(status)));
  }

  Future<void> delete(String date, String slot) => (_db.delete(
    _db.mealSlots,
  )..where((s) => s.date.equals(date) & s.slot.equals(slot))).go();

  Future<void> deleteForDate(String date) =>
      (_db.delete(_db.mealSlots)..where((s) => s.date.equals(date))).go();

  /// Accepts all suggested slots for the week (suggested → accepted).
  Future<void> acceptWeek(DateTime weekStart) async {
    final dates = List.generate(
      7,
      (i) => _fmt(weekStart.add(Duration(days: i))),
    );
    await (_db.update(_db.mealSlots)
          ..where((s) => s.date.isIn(dates) & s.status.equals('suggested')))
        .write(const MealSlotsCompanion(status: Value('accepted')));
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final mealSlotRepositoryProvider = Provider<MealSlotRepository>(
  (ref) => MealSlotRepository(ref.watch(appDatabaseProvider)),
);
