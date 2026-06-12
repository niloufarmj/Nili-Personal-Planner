/// Rollup totals for the Work Time tracker.
class RollupResult {
  const RollupResult({
    required this.todayMinutes,
    required this.weekMinutes,
    required this.monthPerContext,
    required this.savedDays,
    required this.baselineHoursPerWeek,
  });

  final int todayMinutes;
  final int weekMinutes;

  /// contextId → minutes in the current month.
  final Map<int, int> monthPerContext;

  /// Overtime surplus expressed in 8-hour "days".
  final double savedDays;
  final int baselineHoursPerWeek;

  int get weekMinutesOverBaseline => weekMinutes - baselineHoursPerWeek * 60;
}

/// Pure computation layer — injectable for tests.
abstract final class RollupService {
  /// [weekMinutes]  actual minutes worked in the ISO week.
  /// [baselineHoursPerWeek]  configurable target (default 40 h).
  static RollupResult compute({
    required int todayMinutes,
    required int weekMinutes,
    required Map<int, int> monthPerContext,
    required int baselineHoursPerWeek,
  }) {
    final surplusMinutes = weekMinutes - baselineHoursPerWeek * 60;
    final savedDays = surplusMinutes / (8 * 60);
    return RollupResult(
      todayMinutes: todayMinutes,
      weekMinutes: weekMinutes,
      monthPerContext: monthPerContext,
      savedDays: savedDays,
      baselineHoursPerWeek: baselineHoursPerWeek,
    );
  }

  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
