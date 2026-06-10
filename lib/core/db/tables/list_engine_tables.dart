import 'package:drift/drift.dart';

import '../converters/json_map_converter.dart';

/// Generic list container powering ~12 pages.
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get template => text()(); // see template registry in design doc
  IntColumn get parentId => integer().nullable().references(Collections, #id)();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Items in a collection.
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get collectionId => integer().references(Collections, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  IntColumn get priority => integer().nullable()();
  TextColumn get dueDate => text().nullable()();
  TextColumn get doneDate => text().nullable()();
  IntColumn get plannedCostCents => integer().nullable()();
  TextColumn get recurrence => text().nullable()(); // RRULE
  TextColumn get imageBefore => text().nullable()();
  TextColumn get imageAfter => text().nullable()();
  TextColumn get meta => text().nullable().map(
    const NullAwareTypeConverter.wrap(JsonMapConverter()),
  )();
}

/// Subtasks for an item.
class Subtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id)();
  TextColumn get title => text()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  IntColumn get sortOrder => integer().nullable()();
}
