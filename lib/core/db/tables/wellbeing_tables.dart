import 'package:drift/drift.dart';

/// Catalogue of self-care actions.
class WellbeingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // 'meditation','talk to a friend',...
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Log: which action was taken on which date.
class WellbeingLogs extends Table {
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get actionId => integer().references(WellbeingActions, #id)();

  @override
  Set<Column<Object>> get primaryKey => {date, actionId};
}
