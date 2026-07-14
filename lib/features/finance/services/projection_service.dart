import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database.dart';
import '../repositories/recurring_repository.dart';

class ProjectionService {
  ProjectionService(this._db, this._recurringRepo);

  final AppDatabase _db;
  final RecurringRepository _recurringRepo;

  Future<double> getSmartForecast({
    required DateTime targetDate,
    required double plannedCost,
  }) async {
    final today = DateTime.now();

    // 1. Calculate Current Actual Balance
    final allActual = await (_db.select(_db.transactions)
          ..where((t) => t.status.equals('actual')))
        .get();

    int currentBalanceCents = 0;
    for (final tx in allActual) {
      if (tx.direction == 'in') {
        currentBalanceCents += tx.amountCents;
      } else {
        currentBalanceCents -= tx.amountCents;
      }
    }

    if (targetDate.isBefore(today)) {
      return (currentBalanceCents - (plannedCost * 100).round()) / 100.0;
    }

    // 2. Calculate Mean Variable Monthly Spend
    final variableOutcomes = allActual.where((tx) =>
        tx.direction == 'out' &&
        !(tx.note != null && tx.note!.startsWith('Recurring: ')));

    final Map<String, int> monthlySums = {};
    for (final tx in variableOutcomes) {
      if (tx.date.length >= 7) {
        final monthKey = tx.date.substring(0, 7);
        monthlySums[monthKey] = (monthlySums[monthKey] ?? 0) + tx.amountCents;
      }
    }

    double meanVariableSpendCents = 30000.0; // Default 300.00 euros
    if (monthlySums.isNotEmpty) {
      final total = monthlySums.values.fold<int>(0, (sum, val) => sum + val);
      meanVariableSpendCents = total / monthlySums.length;
    }

    if (meanVariableSpendCents < 10000) {
      meanVariableSpendCents = 10000; // clamp to min 100.00 euros
    }

    // 3. Pro-rate variable spend up to targetDate
    final daysRemaining = targetDate.difference(today).inDays;
    final monthsFraction = daysRemaining / 30.0;
    final projectedVariableCents = (monthsFraction * meanVariableSpendCents).round();

    // 4. Project future Recurring Transactions up to targetDate
    final recurring = await _recurringRepo.getAll();
    int projectedRecurringCents = 0;

    for (final rt in recurring) {
      if (!rt.active) continue;

      final parts = rt.startMonth.split('-');
      if (parts.length != 2) continue;
      final startYear = int.tryParse(parts[0]);
      final startMonthVal = int.tryParse(parts[1]);
      if (startYear == null || startMonthVal == null) continue;

      var currentMonth = DateTime(today.year, today.month);
      final targetMonth = DateTime(targetDate.year, targetDate.month);

      while (currentMonth.isBefore(targetMonth) ||
          (currentMonth.year == targetMonth.year && currentMonth.month == targetMonth.month)) {
        final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
        final day = rt.dayOfMonth.clamp(1, lastDay);
        final occurrenceDate = DateTime(currentMonth.year, currentMonth.month, day);

        if (occurrenceDate.isAfter(today) &&
            (occurrenceDate.isBefore(targetDate) ||
                (occurrenceDate.year == targetDate.year &&
                    occurrenceDate.month == targetDate.month &&
                    occurrenceDate.day == targetDate.day))) {
          if (rt.direction == 'in') {
            projectedRecurringCents += rt.amountCents;
          } else {
            projectedRecurringCents -= rt.amountCents;
          }
        }

        currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
      }
    }

    // 5. Project future Planned Transactions up to targetDate
    final allPlanned = await (_db.select(_db.transactions)
          ..where((t) => t.status.equals('planned')))
        .get();

    int projectedPlannedCents = 0;
    final targetDateStr = '${targetDate.year.toString().padLeft(4, '0')}-'
        '${targetDate.month.toString().padLeft(2, '0')}-'
        '${targetDate.day.toString().padLeft(2, '0')}';
    final todayStr = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    for (final tx in allPlanned) {
      if (tx.date.compareTo(todayStr) > 0 && tx.date.compareTo(targetDateStr) <= 0) {
        if (tx.direction == 'in') {
          projectedPlannedCents += tx.amountCents;
        } else {
          projectedPlannedCents -= tx.amountCents;
        }
      }
    }

    final finalCents = currentBalanceCents +
        projectedRecurringCents -
        projectedVariableCents +
        projectedPlannedCents -
        (plannedCost * 100).round();

    return finalCents / 100.0;
  }
}

final projectionServiceProvider = Provider<ProjectionService>((ref) {
  return ProjectionService(
    ref.watch(appDatabaseProvider),
    ref.watch(recurringRepositoryProvider),
  );
});

class SmartForecastParams {
  final DateTime targetDate;
  final double plannedCost;

  SmartForecastParams({required this.targetDate, required this.plannedCost});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartForecastParams &&
          runtimeType == other.runtimeType &&
          targetDate == other.targetDate &&
          plannedCost == other.plannedCost;

  @override
  int get hashCode => targetDate.hashCode ^ plannedCost.hashCode;
}

final smartForecastFamilyProvider =
    FutureProvider.autoDispose.family<double, SmartForecastParams>((ref, params) {
  return ref.watch(projectionServiceProvider).getSmartForecast(
        targetDate: params.targetDate,
        plannedCost: params.plannedCost,
      );
});
