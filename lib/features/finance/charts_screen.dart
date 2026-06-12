import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/transaction_repository.dart';

class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({required this.month, super.key});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Charts',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        children: [
          const SectionHeader(title: 'Spending by Category'),
          const SizedBox(height: 12),
          _CategoryDonut(month: month),
          const SizedBox(height: 32),
          const SectionHeader(title: '6-Month In/Out'),
          const SizedBox(height: 12),
          _SixMonthBars(anchorMonth: month),
        ],
      ),
    );
  }
}

final _chartsMonthTransactionsProvider = StreamProvider.autoDispose
    .family<List<Transaction>, DateTime>(
      (ref, m) => ref
          .watch(transactionRepositoryProvider)
          .watchByMonthFiltered(
            m.year,
            m.month,
            direction: 'out',
            status: 'actual',
          ),
    );

// ── Category donut ────────────────────────────────────────────────────────────

class _CategoryDonut extends ConsumerWidget {
  const _CategoryDonut({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_chartsMonthTransactionsProvider(month));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return txAsync.when(
      loading: () => const AppCard(
        child: SizedBox(
          height: 200,
          child: Center(
            child: ShimmerSkeleton(width: 140, height: 140, borderRadius: 70),
          ),
        ),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (txs) {
        if (txs.isEmpty) {
          return const AppCard(
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No expenses this month',
                  style: TextStyle(color: Colors.grey),
                ),
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
          DesignTokens.rose,
          DesignTokens.sage,
          DesignTokens.peach,
          DesignTokens.lavender,
          DesignTokens.dustyBlue,
          DesignTokens.butter,
          DesignTokens.blush,
          DesignTokens.success,
        ];

        final sections = sorted.indexed.map(((int, MapEntry<String, int>) e) {
          final (i, entry) = e;
          final color = isDark
              ? DesignTokens.adjustColorForDark(palette[i % palette.length])
              : palette[i % palette.length];
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: entry.key,
            color: color,
            radius: 80,
            titleStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
          );
        }).toList();

        return AppCard(
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 36,
              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final months = List.generate(6, (i) {
      return DateTime(anchorMonth.year, anchorMonth.month - 5 + i);
    });

    final futures = months.map(
      (m) =>
          ref.watch(transactionRepositoryProvider).getByMonth(m.year, m.month),
    );

    final greenColor = isDark
        ? DesignTokens.adjustColorForDark(DesignTokens.success)
        : DesignTokens.success;
    final redColor = isDark
        ? DesignTokens.adjustColorForDark(DesignTokens.danger)
        : DesignTokens.danger;

    return FutureBuilder<List<List<Transaction>>>(
      future: Future.wait(futures),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AppCard(
            child: SizedBox(
              height: 220,
              child: Center(
                child: ShimmerSkeleton(width: double.infinity, height: 180),
              ),
            ),
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
                color: greenColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: outCents / 100,
                color: redColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList();

        final monthLabels = months
            .map((m) => '${m.month.toString().padLeft(2, '0')}/${m.year % 100}')
            .toList();

        return AppCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: SizedBox(
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
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthLabels[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? DesignTokens.inkSoftDark
                                    : DesignTokens.inkSoftLight,
                              ),
                            ),
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
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark
                          ? DesignTokens.lineDark
                          : DesignTokens.lineLight,
                      strokeWidth: 1,
                      dashArray: [4, 4], // dotted lines
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
