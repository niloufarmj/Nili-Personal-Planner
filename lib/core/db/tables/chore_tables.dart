import 'package:drift/drift.dart';

import 'list_engine_tables.dart';

/// Log of completed chore occurrences, used to advance the next due date.
class ChoreCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id)();
  TextColumn get completedAt => text()(); // ISO yyyy-MM-dd
  TextColumn get dueDateAtCompletion => text().nullable()(); // ISO yyyy-MM-dd
}
