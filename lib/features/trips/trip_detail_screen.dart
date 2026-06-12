import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import 'trip_edit_sheet.dart';
import 'trip_repository.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(_tripProvider(tripId));
    return tripAsync.when(
      loading: () =>
          const Scaffold(body: LinearProgressIndicator(minHeight: 2)),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (trip) {
        if (trip == null) {
          return const Scaffold(body: Center(child: Text('Trip not found')));
        }
        return _TripDetailView(trip: trip);
      },
    );
  }
}

final _tripProvider = FutureProvider.autoDispose.family<Trip?, int>(
  (ref, id) => ref.watch(tripRepositoryProvider).getById(id),
);

class _TripDetailView extends ConsumerWidget {
  const _TripDetailView({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => TripEditSheet.show(context, existing: trip),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(context, ref, v),
            itemBuilder: (_) => [
              if (trip.status == 'probable')
                const PopupMenuItem(
                  value: 'finalize',
                  child: Text('Mark as Final'),
                ),
              if (trip.status == 'final')
                const PopupMenuItem(value: 'done', child: Text('Mark Done')),
              if (trip.status != 'cancelled')
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel trip'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status + date range
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Status'),
                  trailing: StatusChip(status: trip.status),
                ),
                if (trip.startDate != null && trip.endDate != null)
                  ListTile(
                    leading: const Icon(Icons.date_range),
                    title: const Text('Dates'),
                    subtitle: Text(
                      '${fmt.format(_parseDate(trip.startDate!))} – '
                      '${fmt.format(_parseDate(trip.endDate!))}',
                    ),
                  ),
                if (trip.location != null)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: const Text('Location'),
                    subtitle: Text(trip.location!),
                  ),
                if (trip.budgetCents != null)
                  ListTile(
                    leading: const Icon(Icons.euro_outlined),
                    title: const Text('Budget'),
                    subtitle: Text(
                      '€${(trip.budgetCents! / 100).toStringAsFixed(2)}',
                    ),
                  ),
              ],
            ),
          ),

          if (trip.description != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(trip.description!),
                  ],
                ),
              ),
            ),
          ],

          // Packing list tap-through
          if (trip.packingCollectionId != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('Packing list'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  Routes.collectionPath(trip.packingCollectionId!),
                ),
              ),
            ),
          ],

          // Links
          if (trip.links != null && trip.links!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const SectionHeader(title: 'Links'),
            ...trip.links!.map(
              (link) => AppCard(
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(link, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repo = ref.read(tripRepositoryProvider);
    switch (action) {
      case 'finalize':
        await repo.finalizeTrip(trip.id);
      case 'done':
        await repo.markDone(trip.id);
      case 'cancel':
        final ok = await ConfirmDialog.show(
          context,
          title: 'Cancel trip?',
          message: 'Travel tags for this trip will be removed.',
        );
        if (ok == true) await repo.cancelTrip(trip.id);
      case 'delete':
        final ok = await ConfirmDialog.show(
          context,
          title: 'Delete trip?',
          message: 'This cannot be undone.',
        );
        if (ok == true) {
          await repo.deleteTrip(trip.id);
          if (context.mounted) context.pop();
        }
    }
  }

  static DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}
