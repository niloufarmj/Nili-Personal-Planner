import 'package:drift/drift.dart';

/// Generic key-value store for persisted UI settings (filter state, etc.).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
