import 'package:drift/drift.dart';

import 'list_engine_tables.dart';

/// Work client / project contexts.
class WorkContexts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // 'FreshFX','Tutoring','Startup'
  TextColumn get color => text().nullable()();
}

/// Time entries logged against a work context and optional task.
class TimeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contextId => integer().references(WorkContexts, #id)();
  IntColumn get itemId => integer().nullable().references(Items, #id)();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get minutes => integer()();
  TextColumn get note => text().nullable()();
}
