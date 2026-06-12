import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/transaction_repository.dart';

class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({required this.month, super.key});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Spending by Category'),
          const SizedBox(height: 8),
          _CategoryDonut(month: month),
          const SizedBox(height: 24),
          const SectionHeader(title: '6-Month In/Out'),
          const SizedBox(height: 8),
          _SixMonthBars(anchorMonth: month),
        ],
      ),
    );
  }
}

// ── Category donut ────────────────────────────────────────────────────────────

class _CategoryDonut extends ConsumerWidget {
  const _CategoryDonut({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(
      StreamProvider.autoDispose.family<List<Transaction>, DateTime>(
        (r, m) => r
            .watch(transactionRepositoryProvider)
            .watchByMonthFiltered(
              m.year,
              m.month,
              direction: 'out',
              status: 'actual',
            ),
      )(month),
    );

    return txAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (txs) {
        if (txs.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'No expenses this month',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final totals = <String, int>{};
        for (final tx in txs) {
          totals[tx.category] = (totals[tx.category] ?? 0) + tx.amountCents;
        }

        final sorted = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final palette = [
          Colors.orange,
          Colors.blue,
          Colors.green,
          Colors.red,
          Colors.purple,
          Colors.teal,
          Colors.amber,
          Colors.pink,
        ];

        final sections = sorted.indexed.map(((int, MapEntry<String, int>) e) {
          final (i, entry) = e;
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: entry.key,
            color: palette[i % palette.length],
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList();

        return SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        );
      },
    );
  }
}

// ── 6-month bar chart ─────────────────────────────────────────────────────────

class _SixMonthBars extends ConsumerWidget {
  const _SixMonthBars({required this.anchorMonth});

  final DateTime anchorMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = List.generate(6, (i) {
      var m = DateTime(anchorMonth.year, anchorMonth.month - 5 + i);
      return m;
    });

    final futures = months.map(
      (m) =>
          ref.watch(transactionRepositoryProvider).getByMonth(m.year, m.month),
    );

    return FutureBuilder<List<List<Transaction>>>(
      future: Future.wait(futures),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final barGroups = data.indexed.map(((int, List<Transaction>) e) {
          final (i, txs) = e;
          var inCents = 0;
          var outCents = 0;
          for (final tx in txs) {
            if (tx.status != 'actual') continue;
            if (tx.direction == 'in') {
              inCents += tx.amountCents;
            } else {
              outCents += tx.amountCents;
            }
          }
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: inCents / 100,
                color: Colors.green[400],
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: outCents / 100,
                color: Colors.red[400],
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          );
        }).toList();

        final monthLabels = months
            .map((m) => '${m.month.toString().padLeft(2, '0')}/${m.year % 100}')
            .toList();

        return SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= monthLabels.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        monthLabels[i],
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        );
      },
    );
  }
}
