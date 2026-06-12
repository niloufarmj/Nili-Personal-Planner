/// Severity levels for conflict suggestions.
enum ConflictSeverity { info, warning, error }

/// A single conflict/suggestion card shown on Today.
///
/// Suggestions are dismissible — NEVER auto-modify data.
class ConflictItem {
  const ConflictItem({
    required this.id,
    required this.message,
    required this.severity,
    this.actions = const [],
  });

  /// Stable identifier used to persist dismissals (rule:date:entityId).
  final String id;
  final String message;
  final ConflictSeverity severity;
  final List<ConflictAction> actions;
}

/// A one-tap action offered alongside a conflict card.
class ConflictAction {
  const ConflictAction({required this.label, required this.onTap});
  final String label;
  final Future<void> Function() onTap;
}

/// Interface consumed by TodayScreen.
abstract interface class ConflictFeed {
  Stream<List<ConflictItem>> watchConflicts(DateTime date);
}
