import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import 'repositories/period_repository.dart';
import 'services/period_service.dart';
import '../../core/db/database.dart';

class PeriodScreen extends ConsumerStatefulWidget {
  const PeriodScreen({super.key});

  @override
  ConsumerState<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends ConsumerState<PeriodScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Period Tracker'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tracker', icon: Icon(Icons.favorite_outline)),
              Tab(text: 'Analysis & Logs', icon: Icon(Icons.analytics_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TrackerTab(),
            _AnalysisTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tracker Tab ──────────────────────────────────────────────────────────────

class _TrackerTab extends ConsumerWidget {
  const _TrackerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final service = ref.watch(periodServiceProvider);
    final logsAsync = ref.watch(periodLogsStreamProvider);

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        return FutureBuilder<Map<String, dynamic>>(
          future: service.getCycleState(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final state = snapshot.data!;
            final cycleDay = state['cycleDay'] as int;
            final daysUntilNext = state['daysUntilNext'] as int;
            final isOnPeriod = state['isOnPeriod'] as bool;

            // Status message
            String primaryText = '';
            String secondaryText = '';
            Color statusColor = DesignTokens.rose;

            if (logs.isEmpty) {
              primaryText = 'No logs yet';
              secondaryText = 'Log your period start below to begin tracking.';
            } else if (isOnPeriod) {
              primaryText = 'Period Active';
              secondaryText = 'Day $cycleDay of your cycle';
              statusColor = DesignTokens.rose;
            } else if (daysUntilNext < 0) {
              primaryText = 'Period Late';
              secondaryText = '${daysUntilNext.abs()} days overdue';
              statusColor = DesignTokens.warning;
            } else {
              primaryText = 'Cycle Day $cycleDay';
              secondaryText = 'Next period in $daysUntilNext days';
              statusColor = DesignTokens.dustyBlue;
            }

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Cycle Ring Header
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.15),
                        width: 12,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOnPeriod ? Icons.water_drop : Icons.favorite,
                          color: statusColor,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          primaryText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          secondaryText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Log Start / End Button Row
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(isOnPeriod ? 'Edit Period' : 'Log Period Start'),
                        style: FilledButton.styleFrom(
                          backgroundColor: DesignTokens.rose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _logPeriodStart(context, ref),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Ovulation & Fertile Window
                FutureBuilder<Set<String>>(
                  future: ref.watch(predictedOvulationDatesProvider.future),
                  builder: (context, ovulationSnapshot) {
                    final dates = ovulationSnapshot.data ?? {};
                    DateTime? nextOvulation;
                    
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    
                    // Search next ovulation date
                    for (int i = 0; i < 90; i++) {
                      final testDate = today.add(Duration(days: i));
                      final testStr = DateFormat('yyyy-MM-dd').format(testDate);
                      if (dates.contains(testStr)) {
                        nextOvulation = testDate;
                        break;
                      }
                    }

                    if (nextOvulation == null) {
                      return const SizedBox.shrink();
                    }

                    final windowStart = nextOvulation.subtract(const Duration(days: 4));
                    final windowEnd = nextOvulation.add(const Duration(days: 1));
                    final isFertile = !today.isBefore(windowStart) && !today.isAfter(windowEnd);

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bubble_chart_outlined,
                                color: isFertile ? DesignTokens.accentLight : DesignTokens.lavender,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fertility & Ovulation',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isFertile) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: DesignTokens.accentLight.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'HIGH FERTILITY',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: DesignTokens.accentLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Estimated Ovulation: ${DateFormat('MMMM d').format(nextOvulation)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fertile Window: ${DateFormat('MMM d').format(windowStart)} - ${DateFormat('MMM d').format(windowEnd)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Upcoming Predictions Card
                FutureBuilder<List<PeriodPrediction>>(
                  future: service.getPredictions(months: 3),
                  builder: (context, predSnapshot) {
                    final preds = predSnapshot.data ?? [];
                    if (preds.isEmpty) return const SizedBox.shrink();

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upcoming Period Predictions',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...preds.map((p) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(p.startDate),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  Text(
                                    '${p.endDate.difference(p.startDate).inDays + 1} days (estimated)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logPeriodStart(BuildContext context, WidgetRef ref) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;

    if (context.mounted) {
      await ref.read(periodServiceProvider).logPeriodStartToday(pickedDate);
      ref.invalidate(periodLogsStreamProvider);
    }
  }
}

// ── Analysis & Logs Tab ──────────────────────────────────────────────────────

class _AnalysisTab extends ConsumerStatefulWidget {
  const _AnalysisTab();

  @override
  ConsumerState<_AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends ConsumerState<_AnalysisTab> {
  final _cycleLengthCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(periodRepositoryProvider);
    final len = await repo.getDefaultCycleLength();
    final dur = await repo.getDefaultDuration();
    setState(() {
      _cycleLengthCtrl.text = len.toString();
      _durationCtrl.text = dur.toString();
    });
  }

  @override
  void dispose() {
    _cycleLengthCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final logsAsync = ref.watch(periodLogsStreamProvider);

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Cycle Statistics
            FutureBuilder<CycleStats>(
              future: ref.read(periodServiceProvider).getStats(),
              builder: (context, statsSnapshot) {
                final stats = statsSnapshot.data;
                if (stats == null) return const SizedBox.shrink();

                return AppCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        value: '${stats.averageCycleLength} days',
                        label: 'Avg Cycle Length',
                      ),
                      _StatItem(
                        value: '${stats.averageDuration} days',
                        label: 'Avg Duration',
                      ),
                      _StatItem(
                        value: stats.regularity,
                        label: 'Regularity',
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Cycle Length Diagram
            if (logs.length >= 2) ...[
              const SectionHeader(title: 'Cycle Consistency'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Length of past cycles (days)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: _buildCycleLengthChart(logs),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Logs list
            SectionHeader(
              title: 'Cycle History',
              trailing: TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add log'),
                onPressed: () => _addPastLog(context),
              ),
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const EmptyState(
                icon: Icons.history,
                message: 'No cycles logged yet',
                hint: 'Logged period occurrences will appear here.',
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final log = logs[logs.length - 1 - i]; // Reverse chronological
                    final date = DateTime.parse(log.startDate);
                    return ListTile(
                      title: Text(
                        DateFormat('MMMM d, yyyy').format(date),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${log.durationDays} days period'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _deleteLog(log.id),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 28),

            // Tracker Settings
            const SectionHeader(title: 'Cycle Settings'),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cycleLengthCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Default Cycle (days)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Default Period (days)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        );
      },
    );
  }

  Widget _buildCycleLengthChart(List<PeriodLog> logs) {
    final List<BarChartGroupData> groups = [];
    final List<int> cycleLengths = [];
    
    for (int i = 1; i < logs.length; i++) {
      final prevStart = DateTime.parse(logs[i - 1].startDate);
      final currStart = DateTime.parse(logs[i].startDate);
      final length = currStart.difference(prevStart).inDays;
      if (length > 0) {
        cycleLengths.add(length);
      }
    }

    if (cycleLengths.isEmpty) return const SizedBox.shrink();

    // Take the last 6 cycles
    final lastCycles = cycleLengths.length > 5 
        ? cycleLengths.sublist(cycleLengths.length - 5) 
        : cycleLengths;

    for (int i = 0; i < lastCycles.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: lastCycles[i].toDouble(),
              color: DesignTokens.rose,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 45,
        barGroups: groups,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= lastCycles.length) return const SizedBox.shrink();
                return Text(
                  'C-${lastCycles.length - idx}',
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Future<void> _addPastLog(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;

    if (context.mounted) {
      final repo = ref.read(periodRepositoryProvider);
      final defaultDuration = await repo.getDefaultDuration();
      await repo.addLog(pickedDate, defaultDuration);
      ref.invalidate(periodLogsStreamProvider);
    }
  }

  Future<void> _deleteLog(int id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete cycle log?',
      message: 'This will remove the logged occurrence from history.',
    );
    if (confirmed == true) {
      await ref.read(periodRepositoryProvider).deleteLog(id);
      ref.invalidate(periodLogsStreamProvider);
    }
  }

  Future<void> _saveSettings() async {
    final len = int.tryParse(_cycleLengthCtrl.text) ?? 28;
    final dur = int.tryParse(_durationCtrl.text) ?? 5;
    
    final repo = ref.read(periodRepositoryProvider);
    await repo.setDefaultCycleLength(len);
    await repo.setDefaultDuration(dur);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
      FocusScope.of(context).unfocus();
    }
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
          ),
        ),
      ],
    );
  }
}
