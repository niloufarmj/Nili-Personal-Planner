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
