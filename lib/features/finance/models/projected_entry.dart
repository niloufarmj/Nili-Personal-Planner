/// A synthetic transaction projected from a [RecurringTransaction].
/// Not persisted to the database — computed on the fly for forecasting.
class ProjectedEntry {
  const ProjectedEntry({
    required this.amountCents,
    required this.direction,
    required this.category,
    required this.date,
    required this.name,
    required this.recurringId,
  });

  final int amountCents;
  final String direction; // 'in' | 'out'
  final String category;
  final String date; // YYYY-MM-DD
  final String name;
  final int recurringId;
}
