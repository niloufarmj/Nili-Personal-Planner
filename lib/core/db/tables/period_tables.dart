import 'package:drift/drift.dart';

/// Database table for logging actual period cycles.
class PeriodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get startDate => text()(); // Format: YYYY-MM-DD
  IntColumn get durationDays => integer().withDefault(const Constant(5))();
}
