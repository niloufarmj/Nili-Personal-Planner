import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

class SocialRepository {
  const SocialRepository(this._db);

  final AppDatabase _db;

  // ── SocialAccount CRUD ────────────────────────────────────────────────────

  Future<int> createAccount({required String platform, String? goal}) => _db
      .into(_db.socialAccounts)
      .insert(
        SocialAccountsCompanion.insert(platform: platform, goal: Value(goal)),
      );

  Stream<List<SocialAccount>> watchAccounts() => (_db.select(
    _db.socialAccounts,
  )..orderBy([(a) => OrderingTerm(expression: a.platform)])).watch();

  Future<bool> updateAccount(SocialAccount account) =>
      _db.update(_db.socialAccounts).replace(account);

  Future<int> deleteAccount(int id) =>
      (_db.delete(_db.socialAccounts)..where((a) => a.id.equals(id))).go();

  // ── SocialLog CRUD ────────────────────────────────────────────────────────

  Future<int> createLog(SocialLogsCompanion companion) =>
      _db.into(_db.socialLogs).insert(companion);

  Stream<List<SocialLog>> watchLogsForAccount(int accountId) =>
      (_db.select(_db.socialLogs)
            ..where((l) => l.accountId.equals(accountId))
            ..orderBy([
              (l) => OrderingTerm(expression: l.date, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<List<SocialLog>> getLogsForAccount(int accountId) =>
      (_db.select(_db.socialLogs)
            ..where((l) => l.accountId.equals(accountId))
            ..orderBy([
              (l) => OrderingTerm(expression: l.date, mode: OrderingMode.desc),
            ]))
          .get();

  Future<int> deleteLog(int id) =>
      (_db.delete(_db.socialLogs)..where((l) => l.id.equals(id))).go();

  // ── Analytics ─────────────────────────────────────────────────────────────

  /// Consecutive posting days ending today (or yesterday if no post today).
  static int computeStreak(List<SocialLog> logs, DateTime today) {
    final postDates = {
      for (final l in logs)
        if (l.activity == 'post' || l.activity == 'story') l.date,
    };

    if (postDates.isEmpty) return 0;

    final todayStr = _dateStr(today);
    final yestStr = _dateStr(today.subtract(const Duration(days: 1)));
    final DateTime? startDay;

    if (postDates.contains(todayStr)) {
      startDay = today;
    } else if (postDates.contains(yestStr)) {
      startDay = today.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    var streak = 0;
    var day = startDay;
    while (postDates.contains(_dateStr(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Days since the most recent post/story. Null if never posted.
  static int? daysAgoLastPost(List<SocialLog> logs, DateTime today) {
    final postLogs =
        logs
            .where((l) => l.activity == 'post' || l.activity == 'story')
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (postLogs.isEmpty) return null;
    final lastDate = _parseDate(postLogs.first.date);
    return today.difference(lastDate).inDays;
  }

  /// Weekly minute totals for the past [weeks] weeks ending [anchorWeekStart].
  static Map<String, int> weeklyMinutes(
    List<SocialLog> logs,
    DateTime anchorWeekStart,
    int weeks,
  ) {
    final result = <String, int>{};
    for (var w = 0; w < weeks; w++) {
      final start = anchorWeekStart.subtract(
        Duration(days: (weeks - 1 - w) * 7),
      );
      final startStr = _dateStr(start);
      final endStr = _dateStr(start.add(const Duration(days: 6)));
      var total = 0;
      for (final l in logs) {
        if (l.date.compareTo(startStr) >= 0 && l.date.compareTo(endStr) <= 0) {
          total += l.minutesSpent ?? 0;
        }
      }
      result[startStr] = total;
    }
    return result;
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(appDatabaseProvider)),
);
