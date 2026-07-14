import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../repositories/period_repository.dart';
import '../../../core/db/database.dart';

class PeriodPrediction {
  final DateTime startDate;
  final DateTime endDate;
  final bool isEstimated;

  PeriodPrediction({
    required this.startDate,
    required this.endDate,
    required this.isEstimated,
  });

  String get startDateStr =>
      '${startDate.year.toString().padLeft(4, '0')}-'
      '${startDate.month.toString().padLeft(2, '0')}-'
      '${startDate.day.toString().padLeft(2, '0')}';

  String get endDateStr =>
      '${endDate.year.toString().padLeft(4, '0')}-'
      '${endDate.month.toString().padLeft(2, '0')}-'
      '${endDate.day.toString().padLeft(2, '0')}';
}

class CycleStats {
  final int averageCycleLength;
  final int averageDuration;
  final String regularity; // 'Regular', 'Irregular', 'Not enough data'

  CycleStats({
    required this.averageCycleLength,
    required this.averageDuration,
    required this.regularity,
  });
}

class PeriodService {
  PeriodService(this._repo, this._notificationService);

  final PeriodRepository _repo;
  final NotificationService _notificationService;

  static const int notificationId = 1001;

  // ── Stats Calculations ─────────────────────────────────────────────────────

  Future<CycleStats> getStats() async {
    final logs = await _repo.getLogs();
    final defaultCycle = await _repo.getDefaultCycleLength();
    final defaultDuration = await _repo.getDefaultDuration();

    if (logs.isEmpty) {
      return CycleStats(
        averageCycleLength: defaultCycle,
        averageDuration: defaultDuration,
        regularity: 'Not enough data',
      );
    }

    // Average duration
    double totalDuration = 0;
    for (final log in logs) {
      totalDuration += log.durationDays;
    }
    final avgDuration = (totalDuration / logs.length).round();

    if (logs.length < 2) {
      return CycleStats(
        averageCycleLength: defaultCycle,
        averageDuration: avgDuration,
        regularity: 'Not enough data',
      );
    }

    // Average cycle length (days between consecutive starts)
    final List<int> cycleLengths = [];
    for (int i = 1; i < logs.length; i++) {
      final prevStart = DateTime.parse(logs[i - 1].startDate);
      final currStart = DateTime.parse(logs[i].startDate);
      final diff = currStart.difference(prevStart).inDays;
      if (diff > 0) {
        cycleLengths.add(diff);
      }
    }

    if (cycleLengths.isEmpty) {
      return CycleStats(
        averageCycleLength: defaultCycle,
        averageDuration: avgDuration,
        regularity: 'Not enough data',
      );
    }

    final avgCycle =
        (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();

    // Regularity calculation: std deviation or difference of cycle lengths
    bool isRegular = true;
    for (final len in cycleLengths) {
      if ((len - avgCycle).abs() > 4) {
        isRegular = false;
        break;
      }
    }

    return CycleStats(
      averageCycleLength: avgCycle,
      averageDuration: avgDuration,
      regularity: isRegular ? 'Regular' : 'Irregular',
    );
  }

  // ── Predictions ────────────────────────────────────────────────────────────

  Future<List<PeriodPrediction>> getPredictions({int months = 6}) async {
    final logs = await _repo.getLogs();
    if (logs.isEmpty) return [];

    final stats = await getStats();
    final latestLog = logs.last;
    final latestStart = DateTime.parse(latestLog.startDate);

    final List<PeriodPrediction> predictions = [];
    DateTime currentStart = latestStart;

    for (int i = 0; i < months; i++) {
      currentStart = currentStart.add(Duration(days: stats.averageCycleLength));
      final currentEnd =
          currentStart.add(Duration(days: stats.averageDuration - 1));
      predictions.add(
        PeriodPrediction(
          startDate: currentStart,
          endDate: currentEnd,
          isEstimated: true,
        ),
      );
    }

    return predictions;
  }

  // ── Cycle State ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCycleState() async {
    final logs = await _repo.getLogs();
    if (logs.isEmpty) {
      return {
        'inCycle': false,
        'cycleDay': 0,
        'daysUntilNext': 0,
        'isOnPeriod': false,
        'nextStartDate': null,
      };
    }

    final latestLog = logs.last;
    final latestStart = DateTime.parse(latestLog.startDate);
    final today = _todayDate();

    final stats = await getStats();
    final nextPredictions = await getPredictions(months: 1);
    final nextStart = nextPredictions.isNotEmpty
        ? nextPredictions.first.startDate
        : today.add(Duration(days: stats.averageCycleLength));

    final isBeforeLatest = today.isBefore(latestStart);
    final cycleDay =
        isBeforeLatest ? 0 : today.difference(latestStart).inDays + 1;

    // Check if currently on period
    final latestDuration = latestLog.durationDays;
    final latestEnd = latestStart.add(Duration(days: latestDuration - 1));
    final isOnPeriod =
        !today.isBefore(latestStart) && !today.isAfter(latestEnd);

    // Days until next period starts
    int daysUntilNext = nextStart.difference(today).inDays;

    return {
      'inCycle': !isBeforeLatest,
      'cycleDay': cycleDay,
      'daysUntilNext': daysUntilNext,
      'isOnPeriod': isOnPeriod,
      'nextStartDate': nextStart,
    };
  }

  // ── Reminders & Flow ────────────────────────────────────────────────────────

  Future<void> syncReminders() async {
    await _notificationService.cancel(notificationId);

    final enabled = await _repo.getRemindersEnabled();
    if (!enabled) return;

    final logs = await _repo.getLogs();
    if (logs.isEmpty) return;

    final predictions = await getPredictions(months: 1);
    if (predictions.isEmpty) return;

    final nextStart = predictions.first.startDate;
    final today = _todayDate();

    if (today.isBefore(nextStart)) {
      // Schedule reminder for the next estimated start day at 9:00 AM
      final reminderTime = DateTime(
        nextStart.year,
        nextStart.month,
        nextStart.day,
        9,
        0,
      );
      await _notificationService.scheduleAt(
        id: notificationId,
        title: 'Period Tracker',
        body: 'Your period is estimated to start today. Did it start?',
        when: reminderTime,
      );
    } else {
      // We are at or past the estimated start day, and no real period is logged.
      // If we haven't asked or user hasn't completed today's response yet,
      // schedule for tomorrow morning.
      final lastNo = await _repo.getLastNoDate();
      final todayStr = _fmtDate(today);

      if (lastNo == todayStr) {
        // User said "No" today. Schedule reminder for tomorrow at 9:00 AM.
        final tomorrow = today.add(const Duration(days: 1));
        final reminderTime = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          9,
          0,
        );
        await _notificationService.scheduleAt(
          id: notificationId,
          title: 'Period Tracker',
          body: 'Has your period started yet?',
          when: reminderTime,
        );
      } else {
        // They haven't answered "No" today. If it's before 9:00 AM, schedule for today,
        // otherwise schedule for tomorrow 9:00 AM.
        final now = DateTime.now();
        var scheduleDate = today;
        if (now.hour >= 9) {
          scheduleDate = today.add(const Duration(days: 1));
        }
        final reminderTime = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          9,
          0,
        );
        await _notificationService.scheduleAt(
          id: notificationId,
          title: 'Period Tracker',
          body: 'Your period is due. Did it start?',
          when: reminderTime,
        );
      }
    }
  }

  /// Handle "Yes" action from prompt card
  Future<void> logPeriodStartToday(DateTime date) async {
    final stats = await getStats();
    await _repo.addLog(date, stats.averageDuration);
    // Clear last no response date to reset asking state
    await _repo.setLastNoDate('');
    await syncReminders();
  }

  /// Handle "No" / "Not yet" action from prompt card
  Future<void> logNotStartedToday() async {
    final todayStr = _fmtDate(_todayDate());
    await _repo.setLastNoDate(todayStr);
    await syncReminders();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _todayDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final periodServiceProvider = Provider<PeriodService>((ref) {
  return PeriodService(
    ref.watch(periodRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

final periodLogsStreamProvider = StreamProvider<List<PeriodLog>>((ref) {
  return ref.watch(periodRepositoryProvider).watchLogs();
});

final periodPredictionsProvider = FutureProvider<List<PeriodPrediction>>((ref) async {
  // Watch logs to trigger re-computation when database changes
  final logsAsync = ref.watch(periodLogsStreamProvider);
  return logsAsync.when(
    data: (logs) => ref.watch(periodServiceProvider).getPredictions(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final actualPeriodDatesProvider = Provider<Set<String>>((ref) {
  final logs = ref.watch(periodLogsStreamProvider).value ?? [];
  final Set<String> dates = {};
  for (final log in logs) {
    final start = DateTime.parse(log.startDate);
    for (int i = 0; i < log.durationDays; i++) {
      final d = start.add(Duration(days: i));
      dates.add('${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}');
    }
  }
  return dates;
});

final predictedPeriodDatesProvider = FutureProvider<Set<String>>((ref) async {
  final predictions = await ref.watch(periodPredictionsProvider.future);
  final Set<String> dates = {};
  for (final pred in predictions) {
    for (var d = pred.startDate; !d.isAfter(pred.endDate); d = d.add(const Duration(days: 1))) {
      dates.add('${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}');
    }
  }
  return dates;
});

final predictedOvulationDatesProvider = FutureProvider<Set<String>>((ref) async {
  final predictions = await ref.watch(periodPredictionsProvider.future);
  final Set<String> dates = {};
  
  // Predict ovulation for upcoming cycles (14 days before next period start)
  for (final pred in predictions) {
    final ovulationDay = pred.startDate.subtract(const Duration(days: 14));
    dates.add('${ovulationDay.year.toString().padLeft(4, '0')}-'
        '${ovulationDay.month.toString().padLeft(2, '0')}-'
        '${ovulationDay.day.toString().padLeft(2, '0')}');
  }
  
  // Predict ovulation for past cycles based on logged start date + cycle length - 14
  final logs = ref.watch(periodLogsStreamProvider).value ?? [];
  final stats = await ref.watch(periodServiceProvider).getStats();
  for (int i = 0; i < logs.length; i++) {
    final start = DateTime.parse(logs[i].startDate);
    int cycleLength = stats.averageCycleLength;
    if (i < logs.length - 1) {
      final nextStart = DateTime.parse(logs[i + 1].startDate);
      cycleLength = nextStart.difference(start).inDays;
    }
    final ovulationDay = start.add(Duration(days: cycleLength - 14));
    dates.add('${ovulationDay.year.toString().padLeft(4, '0')}-'
        '${ovulationDay.month.toString().padLeft(2, '0')}-'
        '${ovulationDay.day.toString().padLeft(2, '0')}');
  }
  
  return dates;
});
