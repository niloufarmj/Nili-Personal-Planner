import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rrule/rrule.dart';

import '../database.dart';

/// An event occurrence on a concrete date (expanded from rrule or one-off).
class EventOccurrence {
  const EventOccurrence({required this.event, required this.date});

  final Event event;
  final DateTime date;
}

/// Repository for events with RRULE expansion.
class EventRepository {
  const EventRepository(this._db);

  final AppDatabase _db;

  // ── CRUD ────────────────────────────────────────────────────────

  Future<int> createEvent(EventsCompanion companion) =>
      _db.into(_db.events).insert(companion);

  Future<void> updateEvent(Event event) =>
      _db.update(_db.events).replace(event);

  Future<int> deleteEvent(int id) =>
      (_db.delete(_db.events)..where((e) => e.id.equals(id))).go();

  Future<Event?> getEvent(int id) =>
      (_db.select(_db.events)..where((e) => e.id.equals(id))).getSingleOrNull();

  Stream<List<Event>> watchAll() => _db.select(_db.events).watch();

  // ── Recurrence expansion ─────────────────────────────────────────

  /// Returns all event occurrences (one-off + expanded rrule) in [start..end].
  Future<List<EventOccurrence>> expandOccurrences(
    DateTime start,
    DateTime end,
  ) async {
    final allEvents = await _db.select(_db.events).get();
    final result = <EventOccurrence>[];

    for (final event in allEvents) {
      final eventDate = _parseDate(event.date);

      if (event.rrule == null || event.rrule!.isEmpty) {
        // One-off event: include if its date is within window
        if (!eventDate.isBefore(start) && !eventDate.isAfter(end)) {
          result.add(EventOccurrence(event: event, date: eventDate));
        }
      } else {
        // Recurring: expand the rrule within the window
        final occurrences = _expandRrule(
          rruleStr: event.rrule!,
          dtStart: eventDate,
          windowStart: start,
          windowEnd: end,
        );
        for (final occ in occurrences) {
          result.add(EventOccurrence(event: event, date: occ));
        }
      }
    }
    // Sort chronologically
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static DateTime _parseDate(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static List<DateTime> _expandRrule({
    required String rruleStr,
    required DateTime dtStart,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    try {
      // rrule package requires the "RRULE:" property-name prefix.
      final ruleStr = rruleStr.startsWith('RRULE:')
          ? rruleStr
          : 'RRULE:$rruleStr';
      final rule = RecurrenceRule.fromString(ruleStr);
      // Start iteration from windowStart so we skip instances before the window.
      // Use takeWhile to stop as soon as we pass windowEnd (avoids O(n) scan).
      final wStartUtc = DateTime.utc(
        windowStart.year,
        windowStart.month,
        windowStart.day,
      );
      final wEndUtc = DateTime.utc(
        windowEnd.year,
        windowEnd.month,
        windowEnd.day,
        23,
        59,
        59,
      );
      final iterStart = wStartUtc.isBefore(dtStart.toUtc())
          ? dtStart.toUtc()
          : wStartUtc;
      final instances = rule
          .getInstances(start: iterStart)
          .takeWhile((d) => !d.isAfter(wEndUtc))
          .map((d) => DateTime(d.year, d.month, d.day))
          .toList();
      return instances;
    } catch (_) {
      return [];
    }
  }
}

// ── Riverpod provider ────────────────────────────────────────────────────────

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(appDatabaseProvider)),
);
