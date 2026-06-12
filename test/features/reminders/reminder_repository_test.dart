import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';
import 'package:personal_planner/features/reminders/reminder_repository.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late ReminderRepository repo;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_local_notifications uses this channel; stub it so cancel() is
    // a no-op in tests (NotificationService.cancel guards on _initialized, but
    // this stub ensures the plugin itself doesn't throw if ever reached).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => null,
    );
  });

  setUp(() async {
    db = _openDb();
    await DayRepository(db).seedDefaultTagsIfNeeded();
    repo = ReminderRepository(db);
  });

  tearDown(() => db.close());

  // ── isActiveOn (pure, no DB) ─────────────────────────────────────────────────

  group('isActiveOn', () {
    test(
      'open reminder with no windowEnd is active on any date after start',
      () {
        final r = _makeReminder(
          windowStart: '2026-06-01',
          windowEnd: null,
          status: 'open',
        );
        expect(ReminderRepository.isActiveOn(r, '2026-06-01'), isTrue);
        expect(ReminderRepository.isActiveOn(r, '2099-12-31'), isTrue);
      },
    );

    test('returns false before windowStart', () {
      final r = _makeReminder(
        windowStart: '2026-06-10',
        windowEnd: null,
        status: 'open',
      );
      expect(ReminderRepository.isActiveOn(r, '2026-06-09'), isFalse);
    });

    test('returns false after windowEnd', () {
      final r = _makeReminder(
        windowStart: '2026-06-01',
        windowEnd: '2026-06-05',
        status: 'open',
      );
      expect(ReminderRepository.isActiveOn(r, '2026-06-06'), isFalse);
    });

    test('returns true on windowEnd date', () {
      final r = _makeReminder(
        windowStart: '2026-06-01',
        windowEnd: '2026-06-05',
        status: 'open',
      );
      expect(ReminderRepository.isActiveOn(r, '2026-06-05'), isTrue);
    });

    test('closed reminder is never active', () {
      final r = _makeReminder(
        windowStart: '2026-06-01',
        windowEnd: null,
        status: 'done',
      );
      expect(ReminderRepository.isActiveOn(r, '2026-06-01'), isFalse);
    });

    test('dismissed reminder is never active', () {
      final r = _makeReminder(
        windowStart: '2026-06-01',
        windowEnd: null,
        status: 'dismissed',
      );
      expect(ReminderRepository.isActiveOn(r, '2026-06-01'), isFalse);
    });
  });

  // ── CRUD ─────────────────────────────────────────────────────────────────────

  test('create returns an id and is readable via watchAll', () async {
    final id = await repo.create(
      title: 'Buy groceries',
      windowStart: '2026-06-20',
    );
    expect(id, greaterThan(0));
    final all = await repo.watchAll().first;
    expect(all.length, 1);
    expect(all.first.title, 'Buy groceries');
  });

  test('markDone sets status to done', () async {
    final id = await repo.create(title: 'Dentist', windowStart: '2026-06-15');
    await repo.markDone(id);
    final r = await repo.getById(id);
    expect(r?.status, 'done');
  });

  test('dismiss sets status to dismissed', () async {
    final id = await repo.create(
      title: 'Tax filing',
      windowStart: '2026-04-01',
      windowEnd: '2026-04-30',
    );
    await repo.dismiss(id);
    final r = await repo.getById(id);
    expect(r?.status, 'dismissed');
  });

  test('delete removes the reminder', () async {
    final id = await repo.create(title: 'Temp', windowStart: '2026-07-01');
    await repo.delete(id);
    final r = await repo.getById(id);
    expect(r, isNull);
  });

  test('watchActive returns only open reminders within window', () async {
    await repo.create(title: 'Active', windowStart: '2026-06-01');
    final doneId = await repo.create(title: 'Done', windowStart: '2026-06-01');
    await repo.markDone(doneId);
    await repo.create(title: 'Future', windowStart: '2026-08-01');

    final active = await repo.watchActive('2026-06-12').first;
    expect(active.length, 1);
    expect(active.first.title, 'Active');
  });

  test('update replaces reminder fields', () async {
    final id = await repo.create(
      title: 'Original',
      windowStart: '2026-07-01',
      priority: 1,
    );
    final existing = await repo.getById(id);
    await repo.update(existing!.copyWith(title: 'Updated', priority: 3));
    final updated = await repo.getById(id);
    expect(updated?.title, 'Updated');
    expect(updated?.priority, 3);
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Reminder _makeReminder({
  required String windowStart,
  required String? windowEnd,
  required String status,
}) => Reminder(
  id: 1,
  title: 'Test',
  description: null,
  windowStart: windowStart,
  windowEnd: windowEnd,
  status: status,
  priority: 2,
  notifyRule: null,
);
