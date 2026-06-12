import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import 'trip_edit_sheet.dart';
import 'trip_repository.dart';

class TravelPlannerScreen extends ConsumerWidget {
  const TravelPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(_allTripsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Planner')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'trip_fab',
        onPressed: () => TripEditSheet.show(context),
        tooltip: 'New trip',
        child: const Icon(Icons.add),
      ),
      body: allAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trips) {
          final upcoming = trips
              .where((t) => t.status == 'final' && !_isPast(t))
              .toList();
          final probable = trips.where((t) => t.status == 'probable').toList();
          final history = trips
              .where(
                (t) =>
                    t.status == 'done' ||
                    t.status == 'cancelled' ||
                    (t.status == 'final' && _isPast(t)),
              )
              .toList();

          if (trips.isEmpty) {
            return const EmptyState(
              icon: Icons.flight_takeoff,
              message: 'No trips yet',
              hint: 'Tap + to add a trip',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                const SectionHeader(title: 'Upcoming'),
                ...upcoming.map((t) => _TripCard(t)),
                const SizedBox(height: 16),
              ],
              if (probable.isNotEmpty) ...[
                const SectionHeader(title: 'Probable plans'),
                ...probable.map((t) => _TripCard(t)),
                const SizedBox(height: 16),
              ],
              if (history.isNotEmpty) ...[
                const SectionHeader(title: 'History'),
                ...history.map((t) => _TripCard(t)),
              ],
            ],
          );
        },
      ),
    );
  }

  static bool _isPast(Trip t) {
    if (t.endDate == null) return false;
    final p = t.endDate!.split('-');
    final end = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return end.isBefore(DateTime.now());
  }
}

final _allTripsProvider = StreamProvider.autoDispose<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).watchAll(),
);

class _TripCard extends ConsumerWidget {
  const _TripCard(this.trip);
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM yyyy');
    String dateRange = '';
    if (trip.startDate != null && trip.endDate != null) {
      final s = _parseDate(trip.startDate!);
      final e = _parseDate(trip.endDate!);
      dateRange = '${fmt.format(s)} – ${fmt.format(e)}';
    } else if (trip.startDate != null) {
      dateRange = 'From ${fmt.format(_parseDate(trip.startDate!))}';
    }

    return AppCard(
      child: ListTile(
        leading: const Icon(Icons.flight_takeoff),
        title: Text(trip.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateRange.isNotEmpty) Text(dateRange),
            if (trip.location != null) Text(trip.location!),
          ],
        ),
        trailing: StatusChip(status: trip.status),
        onTap: () => context.push(Routes.tripPath(trip.id)),
      ),
    );
  }

  static DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}
