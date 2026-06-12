import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repositories/event_repository.dart';

/// Rendered data for a single calendar cell.
class CalendarDayData {
  const CalendarDayData({
    required this.date,
    this.overlayColor,
    this.activityIcons = const [],
    this.eventOccurrences = const [],
    this.tripBars = const [],
    this.mealDots = 0,
    this.gymSession,
    this.dueDots = 0,
    this.financeDots = 0,
    this.activeReminders = const [],
    this.partnerTags = const [],
    this.partnerEvents = const [],
  });

  final DateTime date;

  /// Full-cell background color from a location tag (linz/salzburg/travel).
  final Color? overlayColor;

  /// Small activity icons (gym dumbbell, briefcase for work, etc.).
  final List<IconData> activityIcons;

  /// Calendar event occurrences for this day.
  final List<EventOccurrence> eventOccurrences;

  /// Trip bars spanning this day (only trips with status 'final').
  final List<Trip> tripBars;

  /// Number of accepted/eaten meal slots.
  final int mealDots;

  /// Gym session on this day, if any.
  final GymSession? gymSession;

  /// Count of items with due_date == this date.
  final int dueDots;

  /// Count of planned finance transactions on this date (future-dated).
  final int financeDots;

  /// Active reminders whose window includes this date.
  final List<Reminder> activeReminders;

  /// Partner-owned tags for the partner strip.
  final List<Tag> partnerTags;

  /// Partner-owned events.
  final List<EventOccurrence> partnerEvents;

  bool get isEmpty =>
      overlayColor == null &&
      activityIcons.isEmpty &&
      eventOccurrences.isEmpty &&
      tripBars.isEmpty &&
      mealDots == 0 &&
      gymSession == null &&
      dueDots == 0 &&
      financeDots == 0 &&
      activeReminders.isEmpty &&
      partnerTags.isEmpty &&
      partnerEvents.isEmpty;
}

/// Which data sources to include in the aggregated view.
class CalendarFilter {
  const CalendarFilter({
    this.showLocation = true,
    this.showGym = true,
    this.showMeals = true,
    this.showWork = true,
    this.showUni = true,
    this.showTravel = true,
    this.showSocial = true,
    this.showTasks = true,
    this.showPartner = true,
    this.showReminders = true,
    this.showFinance = true,
  });

  final bool showLocation;
  final bool showGym;
  final bool showMeals;
  final bool showWork;
  final bool showUni;
  final bool showTravel;
  final bool showSocial;
  final bool showTasks;
  final bool showPartner;
  final bool showReminders;
  final bool showFinance;

  static const all = CalendarFilter();

  CalendarFilter copyWith({
    bool? showLocation,
    bool? showGym,
    bool? showMeals,
    bool? showWork,
    bool? showUni,
    bool? showTravel,
    bool? showSocial,
    bool? showTasks,
    bool? showPartner,
    bool? showReminders,
    bool? showFinance,
  }) => CalendarFilter(
    showLocation: showLocation ?? this.showLocation,
    showGym: showGym ?? this.showGym,
    showMeals: showMeals ?? this.showMeals,
    showWork: showWork ?? this.showWork,
    showUni: showUni ?? this.showUni,
    showTravel: showTravel ?? this.showTravel,
    showSocial: showSocial ?? this.showSocial,
    showTasks: showTasks ?? this.showTasks,
    showPartner: showPartner ?? this.showPartner,
    showReminders: showReminders ?? this.showReminders,
    showFinance: showFinance ?? this.showFinance,
  );
}
