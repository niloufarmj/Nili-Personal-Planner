import 'package:flutter/foundation.dart';

/// Structured metadata model for rich Travel Planner trip workspaces.

enum TicketType {
  airplane('Airplane', '✈️'),
  train('Train', '🚆'),
  bus('Bus', '🚌'),
  boat('Boat / Ferry', '🚢'),
  car('Car / Taxi', '🚗');

  const TicketType(this.label, this.emoji);
  final String label;
  final String emoji;

  static TicketType fromString(String? val) {
    return TicketType.values.firstWhere(
      (e) => e.name == val || e.label.toLowerCase() == val?.toLowerCase(),
      orElse: () => TicketType.airplane,
    );
  }
}

@immutable
class TicketData {
  final TicketType ticketType;
  final String carrier;
  final String flightNumber;
  final String departureDate;
  final String departureTime;
  final String departureAirport;
  final String arrivalAirport;
  final String terminalGate;
  final String seat;
  final String pnrCode;

  const TicketData({
    this.ticketType = TicketType.airplane,
    this.carrier = '',
    this.flightNumber = '',
    this.departureDate = '',
    this.departureTime = '',
    this.departureAirport = '',
    this.arrivalAirport = '',
    this.terminalGate = '',
    this.seat = '',
    this.pnrCode = '',
  });

  bool get isEmpty =>
      carrier.isEmpty &&
      flightNumber.isEmpty &&
      departureAirport.isEmpty &&
      arrivalAirport.isEmpty;

  Map<String, dynamic> toJson() => {
        'ticketType': ticketType.name,
        'carrier': carrier,
        'flightNumber': flightNumber,
        'departureDate': departureDate,
        'departureTime': departureTime,
        'departureAirport': departureAirport,
        'arrivalAirport': arrivalAirport,
        'terminalGate': terminalGate,
        'seat': seat,
        'pnrCode': pnrCode,
      };

  factory TicketData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TicketData();
    return TicketData(
      ticketType: TicketType.fromString(json['ticketType'] as String?),
      carrier: json['carrier'] as String? ?? '',
      flightNumber: json['flightNumber'] as String? ?? '',
      departureDate: json['departureDate'] as String? ?? '',
      departureTime: json['departureTime'] as String? ?? '',
      departureAirport: json['departureAirport'] as String? ?? '',
      arrivalAirport: json['arrivalAirport'] as String? ?? '',
      terminalGate: json['terminalGate'] as String? ?? '',
      seat: json['seat'] as String? ?? '',
      pnrCode: json['pnrCode'] as String? ?? '',
    );
  }
}

@immutable
class TripLocationItem {
  final String id;
  final String name;
  final String category; // Attraction, Food, Hotel, Activity, Shopping
  final String notes;
  final String status; // 'Must Visit', 'Visited', 'Planned'

  const TripLocationItem({
    required this.id,
    required this.name,
    this.category = 'Attraction',
    this.notes = '',
    this.status = 'Must Visit',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'notes': notes,
        'status': status,
      };

  factory TripLocationItem.fromJson(Map<String, dynamic> json) {
    return TripLocationItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Attraction',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'Must Visit',
    );
  }
}

@immutable
class TripTaskItem {
  final String id;
  final String title;
  final bool isDone;

  const TripTaskItem({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
      };

  factory TripTaskItem.fromJson(Map<String, dynamic> json) {
    return TripTaskItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      isDone: json['isDone'] as bool? ?? false,
    );
  }
}

@immutable
class TripExpenseItem {
  final String id;
  final String title;
  final int amountCents;
  final String category; // Travel, Accommodation, Food, Activity, Shopping, Other
  final String date;
  final bool isSyncedToFinance;
  final int? syncedTransactionId;

  const TripExpenseItem({
    required this.id,
    required this.title,
    required this.amountCents,
    this.category = 'Travel',
    required this.date,
    this.isSyncedToFinance = false,
    this.syncedTransactionId,
  });

  TripExpenseItem copyWith({
    bool? isSyncedToFinance,
    int? syncedTransactionId,
  }) {
    return TripExpenseItem(
      id: id,
      title: title,
      amountCents: amountCents,
      category: category,
      date: date,
      isSyncedToFinance: isSyncedToFinance ?? this.isSyncedToFinance,
      syncedTransactionId: syncedTransactionId ?? this.syncedTransactionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amountCents': amountCents,
        'category': category,
        'date': date,
        'isSyncedToFinance': isSyncedToFinance,
        if (syncedTransactionId != null) 'syncedTransactionId': syncedTransactionId,
      };

  factory TripExpenseItem.fromJson(Map<String, dynamic> json) {
    return TripExpenseItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      amountCents: json['amountCents'] as int? ?? 0,
      category: json['category'] as String? ?? 'Travel',
      date: json['date'] as String? ?? DateTime.now().toIso8601String().split('T').first,
      isSyncedToFinance: json['isSyncedToFinance'] as bool? ?? false,
      syncedTransactionId: json['syncedTransactionId'] as int?,
    );
  }
}

@immutable
class TripMetaData {
  final TicketData outboundTicket;
  final TicketData returnTicket;
  final List<TripLocationItem> placesToVisit;
  final List<TripTaskItem> tasks;
  final List<TripExpenseItem> expenses;

  const TripMetaData({
    this.outboundTicket = const TicketData(),
    this.returnTicket = const TicketData(),
    this.placesToVisit = const [],
    this.tasks = const [],
    this.expenses = const [],
  });

  int get totalExpensesCents =>
      expenses.fold(0, (sum, e) => sum + e.amountCents);

  int get unsyncedExpensesCount =>
      expenses.where((e) => !e.isSyncedToFinance).length;

  TripMetaData copyWith({
    TicketData? outboundTicket,
    TicketData? returnTicket,
    List<TripLocationItem>? placesToVisit,
    List<TripTaskItem>? tasks,
    List<TripExpenseItem>? expenses,
  }) {
    return TripMetaData(
      outboundTicket: outboundTicket ?? this.outboundTicket,
      returnTicket: returnTicket ?? this.returnTicket,
      placesToVisit: placesToVisit ?? this.placesToVisit,
      tasks: tasks ?? this.tasks,
      expenses: expenses ?? this.expenses,
    );
  }

  Map<String, dynamic> toJson() => {
        'outbound_ticket': outboundTicket.toJson(),
        'return_ticket': returnTicket.toJson(),
        'places_to_visit': placesToVisit.map((p) => p.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory TripMetaData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripMetaData();
    return TripMetaData(
      outboundTicket: TicketData.fromJson(json['outbound_ticket'] as Map<String, dynamic>?),
      returnTicket: TicketData.fromJson(json['return_ticket'] as Map<String, dynamic>?),
      placesToVisit: (json['places_to_visit'] as List<dynamic>?)
              ?.map((e) => TripLocationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => TripTaskItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      expenses: (json['expenses'] as List<dynamic>?)
              ?.map((e) => TripExpenseItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
