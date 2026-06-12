import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allAsync = ref.watch(_allTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Travel Planner',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'trip_fab',
        backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
        foregroundColor: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        ),
        onPressed: () => TripEditSheet.show(context),
        tooltip: 'New trip',
        child: const Icon(Icons.add),
      ),
      body: allAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: const [
              ShimmerSkeleton(width: double.infinity, height: 100),
              SizedBox(height: 16),
              ShimmerSkeleton(width: double.infinity, height: 100),
            ],
          ),
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              if (upcoming.isNotEmpty) ...[
                const SectionHeader(title: 'Upcoming'),
                const SizedBox(height: 12),
                ...upcoming.map((t) => _TripCard(t)),
                const SizedBox(height: 16),
              ],
              if (probable.isNotEmpty) ...[
                const SectionHeader(title: 'Probable plans'),
                const SizedBox(height: 12),
                ...probable.map((t) => _TripCard(t)),
                const SizedBox(height: 16),
              ],
              if (history.isNotEmpty) ...[
                const SectionHeader(title: 'History'),
                const SizedBox(height: 12),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final fmt = DateFormat('d MMM yyyy');
    String dateRange = '';
    if (trip.startDate != null && trip.endDate != null) {
      final s = _parseDate(trip.startDate!);
      final e = _parseDate(trip.endDate!);
      dateRange = '${fmt.format(s)} – ${fmt.format(e)}';
    } else if (trip.startDate != null) {
      dateRange = 'From ${fmt.format(_parseDate(trip.startDate!))}';
    }

    final badgeBg = DesignTokens.resolvePastelFill(color: DesignTokens.sage, isDark: isDark);
    final iconColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flight_takeoff,
              color: iconColor,
              size: 20,
            ),
          ),
          title: Text(
            trip.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: DesignTokens.fontBody,
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (dateRange.isNotEmpty)
                Text(
                  dateRange,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: DesignTokens.fontCaption,
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                  ),
                ),
              if (trip.location != null)
                Text(
                  trip.location!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: DesignTokens.fontCaption,
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                  ),
                ),
            ],
          ),
          trailing: StatusChip(status: trip.status),
          onTap: () => context.push(Routes.tripPath(trip.id)),
        ),
      ),
    );
  }

  static DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}
