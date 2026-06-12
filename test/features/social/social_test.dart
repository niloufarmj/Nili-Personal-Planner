import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/social/repositories/social_repository.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

SocialLog _log({
  required int id,
  required int accountId,
  required String date,
  String? activity,
  int? minutes,
}) => SocialLog(
  id: id,
  accountId: accountId,
  date: date,
  minutesSpent: minutes,
  activity: activity,
  note: null,
);

void main() {
  late AppDatabase db;
  late SocialRepository repo;

  setUp(() {
    db = _openDb();
    repo = SocialRepository(db);
  });

  tearDown(() => db.close());

  // ── Streak computation ────────────────────────────────────────────────────

  group('SocialRepository.computeStreak', () {
    test('returns 0 when no logs', () {
      expect(SocialRepository.computeStreak([], DateTime(2026, 6, 11)), 0);
    });

    test('streak of 1 when posted today only', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-11', activity: 'post'),
      ];
      expect(SocialRepository.computeStreak(logs, DateTime(2026, 6, 11)), 1);
    });

    test('streak counts consecutive days including today', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-11', activity: 'post'),
        _log(id: 2, accountId: 1, date: '2026-06-10', activity: 'story'),
        _log(id: 3, accountId: 1, date: '2026-06-09', activity: 'post'),
      ];
      expect(SocialRepository.computeStreak(logs, DateTime(2026, 6, 11)), 3);
    });

    test('streak resets on gap', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-11', activity: 'post'),
        // Jun 10 missing
        _log(id: 2, accountId: 1, date: '2026-06-09', activity: 'post'),
      ];
      expect(SocialRepository.computeStreak(logs, DateTime(2026, 6, 11)), 1);
    });

    test('streak counts from yesterday if not posted today', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-10', activity: 'post'),
        _log(id: 2, accountId: 1, date: '2026-06-09', activity: 'story'),
      ];
      expect(SocialRepository.computeStreak(logs, DateTime(2026, 6, 11)), 2);
    });

    test('browse activity does not count for streak', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-11', activity: 'browse'),
      ];
      expect(SocialRepository.computeStreak(logs, DateTime(2026, 6, 11)), 0);
    });

    test('returns 0 when last post was 2+ days ago', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-08', activity: 'post'),
      ];
      expect(SocialRepository.computeStreak(logs, DateTime(2026, 6, 11)), 0);
    });
  });

  // ── daysAgoLastPost ───────────────────────────────────────────────────────

  group('SocialRepository.daysAgoLastPost', () {
    test('returns null with no logs', () {
      expect(
        SocialRepository.daysAgoLastPost([], DateTime(2026, 6, 11)),
        isNull,
      );
    });

    test('returns 0 when posted today', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-11', activity: 'post'),
      ];
      expect(SocialRepository.daysAgoLastPost(logs, DateTime(2026, 6, 11)), 0);
    });

    test('returns correct days-ago count', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-08', activity: 'story'),
      ];
      expect(SocialRepository.daysAgoLastPost(logs, DateTime(2026, 6, 11)), 3);
    });

    test('ignores browse logs', () {
      final logs = [
        _log(id: 1, accountId: 1, date: '2026-06-11', activity: 'browse'),
        _log(id: 2, accountId: 1, date: '2026-06-05', activity: 'post'),
      ];
      expect(SocialRepository.daysAgoLastPost(logs, DateTime(2026, 6, 11)), 6);
    });
  });

  // ── CRUD ──────────────────────────────────────────────────────────────────

  group('SocialRepository CRUD', () {
    test('create and watch account', () async {
      await repo.createAccount(platform: 'Instagram', goal: 'Post 3×/week');
      final accounts = await repo.watchAccounts().first;
      expect(accounts.length, 1);
      expect(accounts.first.platform, 'Instagram');
      expect(accounts.first.goal, 'Post 3×/week');
    });

    test('delete account', () async {
      final id = await repo.createAccount(platform: 'TikTok');
      await repo.deleteAccount(id);
      expect(await repo.watchAccounts().first, isEmpty);
    });

    test('create and watch logs', () async {
      final accId = await repo.createAccount(platform: 'Twitter');
      final logId = await repo.createLog(
        SocialLogsCompanion.insert(
          accountId: accId,
          date: '2026-06-11',
          activity: const Value('post'),
          minutesSpent: const Value(20),
        ),
      );

      final logs = await repo.watchLogsForAccount(accId).first;
      expect(logs.length, 1);
      expect(logs.first.id, logId);
      expect(logs.first.activity, 'post');

      await repo.deleteLog(logId);
      expect(await repo.watchLogsForAccount(accId).first, isEmpty);
    });
  });

  // ── weeklyMinutes chart data ───────────────────────────────────────────────

  test('weeklyMinutes aggregates correctly across weeks', () {
    final logs = [
      _log(
        id: 1,
        accountId: 1,
        date: '2026-06-08',
        minutes: 30,
        activity: 'browse',
      ), // week 1
      _log(
        id: 2,
        accountId: 1,
        date: '2026-06-09',
        minutes: 45,
        activity: 'browse',
      ), // week 1
      _log(
        id: 3,
        accountId: 1,
        date: '2026-06-15',
        minutes: 60,
        activity: 'post',
      ), // week 2
    ];

    // anchorWeekStart = Jun 15 (Mon of week 2), 2 weeks back
    final weekly = SocialRepository.weeklyMinutes(
      logs,
      DateTime(2026, 6, 15),
      2,
    );

    // Week 1: Jun 8 → 30+45 = 75
    // Week 2: Jun 15 → 60
    expect(weekly['2026-06-08'], 75);
    expect(weekly['2026-06-15'], 60);
  });
}
