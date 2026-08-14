import 'package:flutter/foundation.dart';

/// Structured metadata model for rich Travel Planner trip workspaces.

@immutable
class TicketData {
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
class TripMetaData {
  final TicketData outboundTicket;
  final TicketData returnTicket;
  final List<TripLocationItem> placesToVisit;
  final List<TripTaskItem> tasks;

  const TripMetaData({
    this.outboundTicket = const TicketData(),
    this.returnTicket = const TicketData(),
    this.placesToVisit = const [],
    this.tasks = const [],
  });

  TripMetaData copyWith({
    TicketData? outboundTicket,
    TicketData? returnTicket,
    List<TripLocationItem>? placesToVisit,
    List<TripTaskItem>? tasks,
  }) {
    return TripMetaData(
      outboundTicket: outboundTicket ?? this.outboundTicket,
      returnTicket: returnTicket ?? this.returnTicket,
      placesToVisit: placesToVisit ?? this.placesToVisit,
      tasks: tasks ?? this.tasks,
    );
  }

  Map<String, dynamic> toJson() => {
        'outbound_ticket': outboundTicket.toJson(),
        'return_ticket': returnTicket.toJson(),
        'places_to_visit': placesToVisit.map((p) => p.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
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
    );
  }
}
