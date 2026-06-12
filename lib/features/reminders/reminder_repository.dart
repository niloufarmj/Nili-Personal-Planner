import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/services/notification_service.dart';

/// CRUD for reminders with window-active computation and notification scheduling.
class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;

  // ── Queries ──────────────────────────────────────────────────────

  Stream<List<Reminder>> watchAll() => (_db.select(
    _db.reminders,
  )..orderBy([(r) => OrderingTerm(expression: r.windowStart)])).watch();

  Stream<List<Reminder>> watchActive(String date) =>
      (_db.select(_db.reminders)..where(
            (r) =>
                r.status.equals('open') &
                r.windowStart.isSmallerOrEqualValue(date) &
                (r.windowEnd.isNull() | r.windowEnd.isBiggerOrEqualValue(date)),
          ))
          .watch();

  Future<Reminder?> getById(int id) async {
    final rows = await (_db.select(
      _db.reminders,
    )..where((r) => r.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  // ── Create / update / delete ─────────────────────────────────────

  Future<int> create({
    required String title,
    String? description,
    required String windowStart,
    String? windowEnd,
    int priority = 2,
    Map<String, dynamic>? notifyRule,
  }) async {
    final id = await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            title: title,
            description: Value(description),
            windowStart: windowStart,
            windowEnd: Value(windowEnd),
            priority: Value(priority),
            notifyRule: Value(notifyRule),
          ),
        );
    await _scheduleNotifications(id, title, windowStart, windowEnd, notifyRule);
    return id;
  }

  Future<void> update(Reminder reminder) async {
    await _db.update(_db.reminders).replace(reminder);
    await _cancelNotifications(reminder.id);
    await _scheduleNotifications(
      reminder.id,
      reminder.title,
      reminder.windowStart,
      reminder.windowEnd,
      reminder.notifyRule,
    );
  }

  Future<void> markDone(int id) async {
    final r = await getById(id);
    if (r == null) return;
    await _db.update(_db.reminders).replace(r.copyWith(status: 'done'));
    await _cancelNotifications(id);
  }

  Future<void> dismiss(int id) async {
    final r = await getById(id);
    if (r == null) return;
    await _db.update(_db.reminders).replace(r.copyWith(status: 'dismissed'));
    await _cancelNotifications(id);
  }

  Future<void> delete(int id) async {
    await _cancelNotifications(id);
    await (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();
  }

  // ── Window-active helper (pure, testable) ─────────────────────────

  /// Returns true if [date] falls within the reminder's open window.
  static bool isActiveOn(Reminder r, String date) {
    if (r.status != 'open') return false;
    if (date.compareTo(r.windowStart) < 0) return false;
    if (r.windowEnd != null && date.compareTo(r.windowEnd!) > 0) return false;
    return true;
  }

  // ── Notification scheduling ───────────────────────────────────────

  // Notification IDs 400–499 allocated to Agent 5.
  // We use 400 + (reminderId % 100) to stay in range.
  static int _notifId(int reminderId) => 400 + (reminderId % 100);

  Future<void> _scheduleNotifications(
    int id,
    String title,
    String windowStart,
    String? windowEnd,
    Map<String, dynamic>? rule,
  ) async {
    if (rule == null) return;
    final svc = NotificationService();
    final notifId = _notifId(id);

    // Rule shape: { "on_window_start": true, "every_n_days": 3 }
    final onStart = rule['on_window_start'] == true;
    final everyN = rule['every_n_days'] as int?;

    if (onStart) {
      final parts = windowStart.split('-');
      final when = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        9,
      );
      if (when.isAfter(DateTime.now())) {
        await svc.scheduleAt(
          id: notifId,
          title: 'Reminder: $title',
          body: windowEnd != null ? 'Due by $windowEnd' : '',
          when: when,
          payload: '/reminders',
        );
      }
    }

    if (everyN != null && everyN > 0) {
      // Schedule up to 5 occurrences within the window.
      final parts = windowStart.split('-');
      var current = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        9,
      );
      int offset = 0;
      for (var i = 0; i < 5; i++) {
        final candidate = current.add(Duration(days: i * everyN));
        if (candidate.isBefore(DateTime.now())) continue;
        if (windowEnd != null) {
          final ep = windowEnd.split('-');
          final endDt = DateTime(
            int.parse(ep[0]),
            int.parse(ep[1]),
            int.parse(ep[2]),
          );
          if (candidate.isAfter(endDt)) break;
        }
        await svc.scheduleAt(
          id: notifId + offset,
          title: 'Reminder: $title',
          body: '',
          when: candidate,
          payload: '/reminders',
        );
        offset++;
      }
    }
  }

  Future<void> _cancelNotifications(int id) async {
    final svc = NotificationService();
    final base = _notifId(id);
    for (var i = 0; i < 6; i++) {
      await svc.cancel(base + i);
    }
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(ref.watch(appDatabaseProvider)),
);
