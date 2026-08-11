import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/lists/helpers/job_status_helper.dart';

void main() {
  group('JobStatusHelper', () {
    test('updateMetaForStatus sets applied_date when transitioning to applied', () {
      final updated = JobStatusHelper.updateMetaForStatus(null, 'applied');
      expect(updated['applied_date'], isNotNull);
      expect(updated['status_history'], isNotEmpty);
    });

    test('updateMetaForStatus sets interview_date and rejected_date on subsequent transitions', () {
      var meta = JobStatusHelper.updateMetaForStatus({'applied_date': '2026-08-01'}, 'interview');
      expect(meta['applied_date'], '2026-08-01');
      expect(meta['interview_date'], isNotNull);

      meta = JobStatusHelper.updateMetaForStatus(meta, 'rejected');
      expect(meta['rejected_date'], isNotNull);
      expect((meta['status_history'] as List).length, 2);
    });

    test('daysBetween computes day differences correctly', () {
      expect(JobStatusHelper.daysBetween('2026-08-01', '2026-08-10'), 9);
      expect(JobStatusHelper.daysBetween('2026-08-10', '2026-08-10'), 0);
      expect(JobStatusHelper.daysBetween(null, '2026-08-10'), isNull);
    });

    test('calculateMeanDays averages valid target durations', () {
      final item1 = Item(
        id: 1,
        collectionId: 10,
        title: 'Company A',
        status: 'interview',
        meta: {'applied_date': '2026-08-01', 'interview_date': '2026-08-05'},
      );
      final item2 = Item(
        id: 2,
        collectionId: 10,
        title: 'Company B',
        status: 'interview',
        meta: {'applied_date': '2026-08-01', 'interview_date': '2026-08-11'},
      );

      final mean = JobStatusHelper.calculateMeanDays([item1, item2], 'interview_date');
      expect(mean, 7.0); // (4 + 10) / 2 = 7.0
    });
  });
}
