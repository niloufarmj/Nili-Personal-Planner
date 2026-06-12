import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/repositories/event_repository.dart';
import '../../core/design/design.dart';
import '../finance/repositories/transaction_repository.dart';
import '../finance/widgets/transaction_tile.dart';
import '../gym/gym_screen.dart';
import 'day_tag_picker.dart';
import 'event_edit_sheet.dart';

class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({required this.date, super.key});

  final String date; // YYYY-MM-DD

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = _parseDate(date);
    final headerFmt = DateFormat('EEEE, MMMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(headerFmt.format(parsed))),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'day_detail_fab',
        tooltip: 'Add event',
        onPressed: () => EventEditSheet.show(context, initialDate: date),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tags ──────────────────────────────────────────────────────
          const SectionHeader(title: 'Tags'),
          const SizedBox(height: 8),
          DayTagPicker(date: date),
          const SizedBox(height: 20),

          // ── Events ────────────────────────────────────────────────────
          const SectionHeader(title: 'Events'),
          const SizedBox(height: 8),
          _EventsSection(date: date),
          const SizedBox(height: 20),

          // ── Finance (planned transactions) ────────────────────────────
          const SectionHeader(title: 'Finance'),
          const SizedBox(height: 8),
          _FinanceSection(date: date),
          const SizedBox(height: 20),

          // ── Placeholder sections for other agents ─────────────────────
          const SectionHeader(title: 'Meals'),
          const _PlaceholderSection(message: 'Meal planner — coming soon'),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Gym'),
          DayDetailGymSection(date: date),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Due items'),
          const _PlaceholderSection(message: 'Task list — coming soon'),
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

// ── Events section ─────────────────────────────────────────────────────────────

class _EventsSection extends ConsumerWidget {
  const _EventsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventRepo = ref.watch(eventRepositoryProvider);
    final day = _parseDate(date);

    final occAsync = ref.watch(
      FutureProvider.autoDispose((_) => eventRepo.expandOccurrences(day, day)),
    );

    return occAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error loading events: $e'),
      data: (occs) {
        if (occs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'No events today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: occs.map((occ) {
            final e = occ.event;
            final timeStr = e.startTime != null
                ? '${e.startTime}${e.endTime != null ? ' – ${e.endTime}' : ''}'
                : null;
            return AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title),
                subtitle: timeStr != null ? Text(timeStr) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(e.category),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () =>
                          EventEditSheet.show(context, existing: e),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

// ── Finance section ────────────────────────────────────────────────────────────

class _FinanceSection extends ConsumerWidget {
  const _FinanceSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(
      FutureProvider.autoDispose(
        (_) => ref.watch(transactionRepositoryProvider).getByDate(date),
      ),
    );

    return txAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (txs) {
        if (txs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'No transactions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: txs.map((tx) => TransactionTile(transaction: tx)).toList(),
        );
      },
    );
  }
}

// ── Placeholder ────────────────────────────────────────────────────────────────

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }
}
