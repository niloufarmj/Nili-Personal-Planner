import '../../../core/db/database.dart';

class JobStatusHelper {
  static String todayIso() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Returns updated meta map with automatic transition date timestamps.
  static Map<String, dynamic> updateMetaForStatus(
    Map<String, dynamic>? currentMeta,
    String newStatus,
  ) {
    final meta = Map<String, dynamic>.from(currentMeta ?? {});
    final now = todayIso();

    if (newStatus == 'applied' && meta['applied_date'] == null) {
      meta['applied_date'] = now;
    }
    if (newStatus == 'interview' && meta['interview_date'] == null) {
      meta['interview_date'] = now;
    }
    if (newStatus == 'rejected' && meta['rejected_date'] == null) {
      meta['rejected_date'] = now;
    }
    if (newStatus == 'offer' && meta['offer_date'] == null) {
      meta['offer_date'] = now;
    }

    final history = List<Map<String, dynamic>>.from(
      (meta['status_history'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
    );
    history.add({'status': newStatus, 'date': now});
    meta['status_history'] = history;

    return meta;
  }

  /// Returns difference in days between applied_date and a transition date.
  static int? daysBetween(String? startIso, String? endIso) {
    if (startIso == null || endIso == null) return null;
    try {
      final start = DateTime.parse(startIso);
      final end = DateTime.parse(endIso);
      return end.difference(start).inDays;
    } catch (_) {
      return null;
    }
  }

  /// Calculates mean duration in days from 'applied_date' to a target date field.
  static double calculateMeanDays(List<Item> items, String targetDateField) {
    final durations = <int>[];
    for (final item in items) {
      final meta = item.meta;
      if (meta == null) continue;
      final applied = meta['applied_date'] as String?;
      final target = meta[targetDateField] as String?;
      final diff = daysBetween(applied, target);
      if (diff != null && diff >= 0) {
        durations.add(diff);
      }
    }
    if (durations.isEmpty) return 0.0;
    final sum = durations.fold<int>(0, (a, b) => a + b);
    return sum / durations.length;
  }
}
