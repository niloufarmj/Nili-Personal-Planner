import 'package:drift/drift.dart';

import 'list_engine_tables.dart';
import 'core_day_tables.dart';

/// Expense and income transactions (actual and planned).
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get amountCents => integer()();
  TextColumn get direction => text()(); // 'in' | 'out'
  TextColumn get status => text()(); // 'actual' | 'planned'
  TextColumn get category =>
      text()(); // 'rent','food','transport','travel','shopping','income',...
  TextColumn get note => text().nullable()();
  IntColumn get itemId => integer().nullable().references(Items, #id)();
  IntColumn get tripId => integer().nullable().references(Trips, #id)();
}

/// Subscriptions, rent, salary — expanded for monthly forecasts.
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get amountCents => integer()();
  TextColumn get direction => text()(); // 'in' | 'out'
  IntColumn get dayOfMonth => integer()();
  TextColumn get startMonth => text()(); // 'YYYY-MM'
  TextColumn get endMonth => text().nullable()();
  TextColumn get category => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Outstanding debts and loans.
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text()();
  IntColumn get amountCents => integer()();
  TextColumn get direction => text()(); // 'i_owe' | 'owes_me'
  TextColumn get note => text().nullable()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
}
