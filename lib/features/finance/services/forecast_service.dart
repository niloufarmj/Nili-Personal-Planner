import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../models/forecast_result.dart';
import '../models/projected_entry.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/transaction_repository.dart';

class ForecastService {
  const ForecastService(this._txRepo, this._recurringRepo);

  final TransactionRepository _txRepo;
  final RecurringRepository _recurringRepo;

  /// Fetches data and runs [compute] for [month].
  Future<ForecastResult> computeForMonth(DateTime month) async {
    await syncRecurringTransactions();
    final transactions = await _txRepo.getByMonth(month.year, month.month);
    final projected = await _recurringRepo.expandForMonth(month);
    return compute(
      transactions: transactions,
      projected: projected,
      today: DateTime.now(),
    );
  }

  // ── Pure computation ──────────────────────────────────────────────────────

  /// Pure function — safe to call in tests with synthetic data.
  static ForecastResult compute({
    required List<Transaction> transactions,
    required List<ProjectedEntry> projected,
    required DateTime today,
  }) {
    final todayStr = _dateStr(today);

    var actualIn = 0;
    var actualOut = 0;
    var plannedIn = 0;
    var plannedOut = 0;
    final catBreakdown = <String, int>{};

    for (final tx in transactions) {
      if (tx.status == 'actual') {
        if (tx.direction == 'in') {
          actualIn += tx.amountCents;
          catBreakdown[tx.category] =
              (catBreakdown[tx.category] ?? 0) + tx.amountCents;
        } else {
          actualOut += tx.amountCents;
          catBreakdown[tx.category] =
              (catBreakdown[tx.category] ?? 0) - tx.amountCents;
        }
      } else if (tx.status == 'planned') {
        if (tx.direction == 'in') {
          plannedIn += tx.amountCents;
        } else {
          plannedOut += tx.amountCents;
        }
      }
    }

    // Only projected entries after today contribute to the "remaining" figure.
    var projIn = 0;
    var projOut = 0;
    for (final p in projected) {
      if (p.date.compareTo(todayStr) > 0) {
        if (p.direction == 'in') {
          projIn += p.amountCents;
          catBreakdown[p.category] =
              (catBreakdown[p.category] ?? 0) + p.amountCents;
        } else {
          projOut += p.amountCents;
          catBreakdown[p.category] =
              (catBreakdown[p.category] ?? 0) - p.amountCents;
        }
      }
    }

    final endBalance =
        (actualIn - actualOut) + (projIn - projOut) + (plannedIn - plannedOut);

    return ForecastResult(
      actualInCents: actualIn,
      actualOutCents: actualOut,
      projectedRemainingInCents: projIn,
      projectedRemainingOutCents: projOut,
      plannedInCents: plannedIn,
      plannedOutCents: plannedOut,
      estimatedEndBalanceCents: endBalance,
      categoryBreakdown: Map.unmodifiable(catBreakdown),
    );
  }

  Future<void> syncRecurringTransactions() async {
    final now = DateTime.now();
    final recurring = await _recurringRepo.getAll();

    for (final rt in recurring) {
      if (!rt.active) continue;

      final parts = rt.startMonth.split('-');
      if (parts.length != 2) continue;
      final startYear = int.tryParse(parts[0]);
      final startMonthVal = int.tryParse(parts[1]);
      if (startYear == null || startMonthVal == null) continue;

      var current = DateTime(startYear, startMonthVal);
      final limit = DateTime(now.year, now.month);

      while (current.isBefore(limit) ||
          (current.year == limit.year && current.month == limit.month)) {
        final lastDay = DateTime(current.year, current.month + 1, 0).day;
        final day = rt.dayOfMonth.clamp(1, lastDay);
        final occurrenceDate = DateTime(current.year, current.month, day);

        if (!occurrenceDate.isAfter(now)) {
          final dateStr = '${occurrenceDate.year.toString().padLeft(4, '0')}-'
              '${occurrenceDate.month.toString().padLeft(2, '0')}-'
              '${occurrenceDate.day.toString().padLeft(2, '0')}';

          final noteText = 'Recurring: ${rt.name}';

          final existing = await _txRepo.getByDate(dateStr);
          final alreadySynced =
              existing.any((tx) => tx.note == noteText && tx.status == 'actual');

          if (!alreadySynced) {
            await _txRepo.create(
              TransactionsCompanion.insert(
                date: dateStr,
                amountCents: rt.amountCents,
                direction: rt.direction,
                status: 'actual',
                category: rt.category,
                note: Value(noteText),
              ),
            );
          }
        }

        current = DateTime(current.year, current.month + 1);
      }
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final forecastServiceProvider = Provider<ForecastService>(
  (ref) => ForecastService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(recurringRepositoryProvider),
  ),
);
