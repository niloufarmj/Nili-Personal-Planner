import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/repositories/event_repository.dart';
import '../design/app_colors.dart';
import 'calendar_day_data.dart';

/// Merges all data sources into per-day [CalendarDayData] for a date range.
class CalendarAggregator {
  const CalendarAggregator(this._db, this._eventRepo);

  final AppDatabase _db;
  final EventRepository _eventRepo;

  /// Returns a map keyed by 'YYYY-MM-DD' for every day in [start]..[end].
  Future<Map<String, CalendarDayData>> getDataForRange(
    DateTime start,
    DateTime end, {
    CalendarFilter filter = CalendarFilter.all,
  }) async {
    // Build skeleton — every day in window gets an entry.
    final result = <String, _MutableDayData>{};
    for (var d = _dayOnly(start);
        !d.isAfter(_dayOnly(end));
        d = d.add(const Duration(days: 1))) {
      result[_fmt(d)] = _MutableDayData(d);
    }

    await Future.wait([
      if (filter.showLocation || filter.showGym || filter.showWork)
        _applyDayTags(result, start, end, filter),
      _applyEvents(result, start, end, filter),
      if (filter.showTravel) _applyTrips(result, start, end),
      if (filter.showReminders) _applyReminders(result, start, end),
      if (filter.showMeals) _applyMealDots(result, start, end),
      if (filter.showGym) _applyGymSessions(result, start, end),
      if (filter.showTasks) _applyDueDots(result, start, end),
    ]);

    return result.map((k, v) => MapEntry(k, v.build()));
  }

  // ── Day tags (location overlays + activity icons) ────────────────────────

  Future<void> _applyDayTags(
    Map<String, _MutableDayData> result,
    DateTime start,
    DateTime end,
    CalendarFilter filter,
  ) async {
    final startStr = _fmt(_dayOnly(start));
    final endStr = _fmt(_dayOnly(end));

    final rows = await (_db.select(_db.dayTags)
          ..where(
            (dt) => dt.date.isBiggerOrEqualValue(startStr) &
                dt.date.isSmallerOrEqualValue(endStr),
          ))
        .get();

    if (rows.isEmpty) return;

    // Load all tags in one query.
    final tagIds = rows.map((r) => r.tagId).toSet().toList();
    final tags = await (_db.select(_db.tags)
          ..where((t) => t.id.isIn(tagIds)))
        .get();
    final tagById = {for (final t in tags) t.id: t};

    for (final row in rows) {
      final day = result[row.date];
      if (day == null) continue;
      final tag = tagById[row.tagId];
      if (tag == null) continue;

      if (tag.kind == 'location') {
        if (!filter.showLocation) continue;
        final c = AppColors.forTagName(tag.name);
        // travel wins; then first-set wins.
        if (tag.name.toLowerCase() == 'travel') {
          day.overlayColor = c;
        } else {
          day.overlayColor ??= c;
        }
      } else if (tag.kind == 'partner') {
        if (!filter.showPartner) continue;
        day.partnerTags.add(tag);
      } else {
        // activity / special
        final icon = _iconForTag(tag.name, filter);
        if (icon != null) day.activityIcons.add(icon);
      }
    }
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<void> _applyEvents(
    Map<String, _MutableDayData> result,
    DateTime start,
    DateTime end,
    CalendarFilter filter,
  ) async {
    final occurrences = await _eventRepo.expandOccurrences(start, end);
    for (final occ in occurrences) {
      final day = result[_fmt(occ.date)];
      if (day == null) continue;
      if (occ.event.owner == 'partner') {
        if (!filter.showPartner) continue;
        day.partnerEvents.add(occ);
      } else {
        // Apply category-level filters
        final cat = occ.event.category;
        if (cat == 'uni' && !filter.showUni) continue;
        if (cat == 'work' && !filter.showWork) continue;
        if (cat == 'social' && !filter.showSocial) continue;
        day.events.add(occ);
      }
    }
  }

  // ── Trips (range bars) ────────────────────────────────────────────────────

  Future<void> _applyTrips(
    Map<String, _MutableDayData> result,
    DateTime start,
    DateTime end,
  ) async {
    final trips = await (_db.select(_db.trips)
          ..where((t) => t.status.equals('final')))
        .get();

    for (final trip in trips) {
      if (trip.startDate == null || trip.endDate == null) continue;
      final ts = _parseDate(trip.startDate!);
      final te = _parseDate(trip.endDate!);
      // Clamp to window
      final rangeStart = ts.isBefore(start) ? start : ts;
      final rangeEnd = te.isAfter(end) ? end : te;
      if (rangeStart.isAfter(rangeEnd)) continue;
      for (var d = _dayOnly(rangeStart);
          !d.isAfter(_dayOnly(rangeEnd));
          d = d.add(const Duration(days: 1))) {
        result[_fmt(d)]?.tripBars.add(trip);
      }
    }
  }

  // ── Reminders (banner windows) ─────────────────────────────────────────────

  Future<void> _applyReminders(
    Map<String, _MutableDayData> result,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = _fmt(_dayOnly(start));
    final endStr = _fmt(_dayOnly(end));

    // Active reminders whose window overlaps with [start..end].
    final reminders = await (_db.select(_db.reminders)
          ..where(
            (r) =>
                r.status.equals('open') &
                r.windowStart.isSmallerOrEqualValue(endStr) &
                (r.windowEnd.isNull() |
                    r.windowEnd.isBiggerOrEqualValue(startStr)),
          ))
        .get();

    for (final rem in reminders) {
      final ws = _parseDate(rem.windowStart);
      final we =
          rem.windowEnd != null ? _parseDate(rem.windowEnd!) : _dayOnly(end);
      final rangeStart = ws.isBefore(start) ? start : ws;
      final rangeEnd = we.isAfter(end) ? end : we;
      if (rangeStart.isAfter(rangeEnd)) continue;
      for (var d = _dayOnly(rangeStart);
          !d.isAfter(_dayOnly(rangeEnd));
          d = d.add(const Duration(days: 1))) {
        result[_fmt(d)]?.reminders.add(rem);
      }
    }
  }

  // ── Meal dots ─────────────────────────────────────────────────────────────

  Future<void> _applyMealDots(
    Map<String, _MutableDayData> result,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = _fmt(_dayOnly(start));
    final endStr = _fmt(_dayOnly(end));

    final slots = await (_db.select(_db.mealSlots)
          ..where(
            (ms) =>
                ms.date.isBiggerOrEqualValue(startStr) &
                ms.date.isSmallerOrEqualValue(endStr),
          ))
        .get();

    for (final slot in slots) {
      final day = result[slot.date];
      if (day != null) day.mealDots++;
    }
  }

  // ── Gym sessions ──────────────────────────────────────────────────────────

  Future<void> _applyGymSessions(
    Map<String, _MutableDayData> result,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = _fmt(_dayOnly(start));
    final endStr = _fmt(_dayOnly(end));

    final sessions = await (_db.select(_db.gymSessions)
          ..where(
            (gs) =>
                gs.date.isBiggerOrEqualValue(startStr) &
                gs.date.isSmallerOrEqualValue(endStr),
          ))
        .get();

    for (final session in sessions) {
      final day = result[session.date];
      // Keep only the first session per day (most recent insert wins in DB order).
      day?.gymSession ??= session;
    }
  }

  // ── Due dots (items.dueDate) ───────────────────────────────────────────────

  Future<void> _applyDueDots(
    Map<String, _MutableDayData> result,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = _fmt(_dayOnly(start));
    final endStr = _fmt(_dayOnly(end));

    final items = await (_db.select(_db.items)
          ..where(
            (i) =>
                i.dueDate.isNotNull() &
                i.dueDate.isBiggerOrEqualValue(startStr) &
                i.dueDate.isSmallerOrEqualValue(endStr),
          ))
        .get();

    for (final item in items) {
      if (item.dueDate == null) continue;
      final day = result[item.dueDate!];
      if (day != null) day.dueDots++;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static IconData? _iconForTag(String name, CalendarFilter filter) =>
      switch (name.toLowerCase()) {
        'gym' => filter.showGym ? Icons.fitness_center : null,
        'work' => filter.showWork ? Icons.work_outline : null,
        'reza-day' || 'reza_day' => filter.showPartner ? Icons.favorite : null,
        _ => null,
      };
}

// ── Mutable builder accumulating per-day data ─────────────────────────────────

class _MutableDayData {
  _MutableDayData(this.date);

  final DateTime date;
  Color? overlayColor;
  final List<IconData> activityIcons = [];
  final List<EventOccurrence> events = [];
  final List<Trip> tripBars = [];
  int mealDots = 0;
  GymSession? gymSession;
  int dueDots = 0;
  final List<Reminder> reminders = [];
  final List<Tag> partnerTags = [];
  final List<EventOccurrence> partnerEvents = [];

  CalendarDayData build() => CalendarDayData(
    date: date,
    overlayColor: overlayColor,
    activityIcons: List.unmodifiable(activityIcons),
    eventOccurrences: List.unmodifiable(events),
    tripBars: List.unmodifiable(tripBars),
    mealDots: mealDots,
    gymSession: gymSession,
    dueDots: dueDots,
    activeReminders: List.unmodifiable(reminders),
    partnerTags: List.unmodifiable(partnerTags),
    partnerEvents: List.unmodifiable(partnerEvents),
  );
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final calendarAggregatorProvider = Provider<CalendarAggregator>(
  (ref) => CalendarAggregator(
    ref.watch(appDatabaseProvider),
    ref.watch(eventRepositoryProvider),
  ),
);
