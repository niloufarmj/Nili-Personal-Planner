import 'package:drift/drift.dart';

/// Social media account tracking.
class SocialAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get platform => text()();
  TextColumn get goal => text().nullable()();
}

/// Daily social media usage log.
class SocialLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(SocialAccounts, #id)();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get minutesSpent => integer().nullable()();
  TextColumn get activity =>
      text().nullable()(); // 'post'|'story'|'comment'|'browse'
  TextColumn get note => text().nullable()();
}
