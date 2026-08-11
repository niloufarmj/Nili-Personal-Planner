import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/design/design.dart';
import '../helpers/job_status_helper.dart';

class JobAnalyticsWidget extends StatelessWidget {
  const JobAnalyticsWidget({required this.items, super.key});

  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No job items in this list yet.\nAdd job entries to see analytics!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      );
    }

    int researching = 0;
    int applied = 0;
    int interview = 0;
    int rejected = 0;
    int offer = 0;

    final Map<String, int> dailyApps = {};

    for (final item in items) {
      switch (item.status) {
        case 'researching':
          researching++;
          break;
        case 'applied':
          applied++;
          break;
        case 'interview':
          interview++;
          break;
        case 'rejected':
          rejected++;
          break;
        case 'offer':
          offer++;
          break;
        default:
          researching++;
          break;
      }

      final appliedDate = item.meta?['applied_date'] as String?;
      if (appliedDate != null && appliedDate.isNotEmpty) {
        dailyApps[appliedDate] = (dailyApps[appliedDate] ?? 0) + 1;
      }
    }

    final totalAppliedOrLater = applied + interview + rejected + offer;
    final offerRate = totalAppliedOrLater > 0 ? (offer / totalAppliedOrLater) * 100 : 0.0;
    final rejectionRate = totalAppliedOrLater > 0 ? (rejected / totalAppliedOrLater) * 100 : 0.0;
    final interviewRate = totalAppliedOrLater > 0 ? (interview / totalAppliedOrLater) * 100 : 0.0;

    final meanInterviewDays = JobStatusHelper.calculateMeanDays(items, 'interview_date');
    final meanRejectedDays = JobStatusHelper.calculateMeanDays(items, 'rejected_date');
    final meanOfferDays = JobStatusHelper.calculateMeanDays(items, 'offer_date');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Key Metrics Overview ──────────────────────────────────────────
          Text('Key Metrics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Applications',
                  value: '$totalAppliedOrLater',
                  subtitle: '${items.length} total tracked',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Offer Rate',
                  value: '${offerRate.toStringAsFixed(1)}%',
                  subtitle: '$offer offers',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Rejection Rate',
                  value: '${rejectionRate.toStringAsFixed(1)}%',
                  subtitle: '$rejected rejected',
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Mean Response Duration ─────────────────────────────────────────
          Text('Mean Response Time', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DurationStat(
                  label: 'To Interview',
                  days: meanInterviewDays,
                  color: const Color(0xFF1E88E5),
                ),
                _DurationStat(
                  label: 'To Rejection',
                  days: meanRejectedDays,
                  color: const Color(0xFFE53935),
                ),
                _DurationStat(
                  label: 'To Offer',
                  days: meanOfferDays,
                  color: const Color(0xFF43A047),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Applications Per Day Chart ──────────────────────────────────────
          Text('Daily Applications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: SizedBox(
              height: 180,
              child: _DailyApplicationsChart(dailyApps: dailyApps),
            ),
          ),
          const SizedBox(height: 20),

          // ── Status Breakdown Pie Chart ──────────────────────────────────────
          Text('Status Breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: [
                        if (researching > 0)
                          PieChartSectionData(
                            color: const Color(0xFF9E9E9E),
                            value: researching.toDouble(),
                            title: '$researching',
                            radius: 32,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        if (applied > 0)
                          PieChartSectionData(
                            color: const Color(0xFFFBC02D),
                            value: applied.toDouble(),
                            title: '$applied',
                            radius: 32,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
                          ),
                        if (interview > 0)
                          PieChartSectionData(
                            color: const Color(0xFF1E88E5),
                            value: interview.toDouble(),
                            title: '$interview',
                            radius: 32,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        if (rejected > 0)
                          PieChartSectionData(
                            color: const Color(0xFFE53935),
                            value: rejected.toDouble(),
                            title: '$rejected',
                            radius: 32,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        if (offer > 0)
                          PieChartSectionData(
                            color: const Color(0xFF43A047),
                            value: offer.toDouble(),
                            title: '$offer',
                            radius: 32,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendItem(color: const Color(0xFF9E9E9E), label: 'Researching', count: researching),
                      _LegendItem(color: const Color(0xFFFBC02D), label: 'Applied', count: applied),
                      _LegendItem(color: const Color(0xFF1E88E5), label: 'Interview', count: interview),
                      _LegendItem(color: const Color(0xFFE53935), label: 'Rejected', count: rejected),
                      _LegendItem(color: const Color(0xFF43A047), label: 'Offer', count: offer),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _DurationStat extends StatelessWidget {
  const _DurationStat({
    required this.label,
    required this.days,
    required this.color,
  });

  final String label;
  final double days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          days > 0 ? '${days.toStringAsFixed(1)}d' : '—',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _DailyApplicationsChart extends StatelessWidget {
  const _DailyApplicationsChart({required this.dailyApps});

  final Map<String, int> dailyApps;

  @override
  Widget build(BuildContext context) {
    if (dailyApps.isEmpty) {
      return const Center(
        child: Text(
          'No application dates logged yet.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    final sortedDates = dailyApps.keys.toList()..sort();
    final recentDates = sortedDates.length > 10 ? sortedDates.sublist(sortedDates.length - 10) : sortedDates;

    final maxVal = recentDates.fold<int>(0, (prev, d) => (dailyApps[d] ?? 0) > prev ? dailyApps[d]! : prev);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxVal + 1).toDouble(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (val, meta) {
                if (val % 1 == 0) {
                  return Text(
                    val.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < recentDates.length) {
                  final raw = recentDates[idx];
                  try {
                    final dt = DateTime.parse(raw);
                    return Text(
                      DateFormat('d/M').format(dt),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    );
                  } catch (_) {
                    return Text(raw, style: const TextStyle(fontSize: 9, color: Colors.grey));
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: recentDates.asMap().entries.map((e) {
          final idx = e.key;
          final date = e.value;
          final count = dailyApps[date] ?? 0;

          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: Colors.amber.shade700,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
