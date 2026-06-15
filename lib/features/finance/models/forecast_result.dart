/// Result of [ForecastService.compute] for a single month.
class ForecastResult {
  const ForecastResult({
    required this.actualInCents,
    required this.actualOutCents,
    required this.projectedRemainingInCents,
    required this.projectedRemainingOutCents,
    required this.plannedInCents,
    required this.plannedOutCents,
    required this.estimatedEndBalanceCents,
    required this.categoryBreakdown,
  });

  final int actualInCents;
  final int actualOutCents;

  /// Recurring entries after today that have not yet been actualised.
  final int projectedRemainingInCents;
  final int projectedRemainingOutCents;

  /// Explicitly-planned (status='planned') transactions in the month.
  final int plannedInCents;
  final int plannedOutCents;

  /// (actual net) + (projected net) + (planned net).
  final int estimatedEndBalanceCents;

  /// Net cents per category (positive = income surplus, negative = expense).
  final Map<String, int> categoryBreakdown;

  int get actualNetCents => actualInCents - actualOutCents;
  int get projectedRemainingNetCents =>
      projectedRemainingInCents - projectedRemainingOutCents;
  int get plannedNetCents => plannedInCents - plannedOutCents;
}
