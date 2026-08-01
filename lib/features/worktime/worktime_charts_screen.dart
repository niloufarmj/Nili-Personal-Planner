import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/worktime_repository.dart';

enum ChartScope { day, week, month }

class WorktimeChartsScreen extends ConsumerStatefulWidget {
  const WorktimeChartsScreen({super.key});

  @override
  ConsumerState<WorktimeChartsScreen> createState() => _WorktimeChartsScreenState();
}

class _WorktimeChartsScreenState extends ConsumerState<WorktimeChartsScreen> {
  int? _selectedContextId; // null means 'All Positions'
  ChartScope _scope = ChartScope.day;

  // Navigation states
  late DateTime _currentWeekStart; // Monday of target week
  late DateTime _currentYearStart;  // January 1st of target year

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    _currentYearStart = DateTime(now.year);
  }

  void _next() {
    setState(() {
      if (_scope == ChartScope.day) {
        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      } else if (_scope == ChartScope.month) {
        _currentYearStart = DateTime(_currentYearStart.year + 1);
      }
    });
  }

  void _prev() {
    setState(() {
      if (_scope == ChartScope.day) {
        _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      } else if (_scope == ChartScope.month) {
        _currentYearStart = DateTime(_currentYearStart.year - 1);
      }
    });
  }

  String _getRangeText() {
    if (_scope == ChartScope.day) {
      final end = _currentWeekStart.add(const Duration(days: 6));
      final fmt = DateFormat('MMM d');
      return '${fmt.format(_currentWeekStart)} – ${fmt.format(end)}, ${_currentWeekStart.year}';
    } else if (_scope == ChartScope.week) {
      return 'Last 6 Weeks';
    } else {
      return 'Year ${_currentYearStart.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    final contextsAsync = ref.watch(workContextsProvider);
    final entriesAsync = ref.watch(workEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Work Analytics',
          style: theme.textTheme.headlineLarge?.copyWith(color: inkColor),
        ),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (entries) => contextsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (contexts) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                // Filters Card
                _buildFiltersCard(contexts),
                const SizedBox(height: 16),

                // Chart Container Card
                _buildChartCard(entries, contexts),
                const SizedBox(height: 16),

                // Summary Stats Card
                _buildStatsCard(entries, contexts),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFiltersCard(List<WorkContext> contexts) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Position / Job',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedContextId,
                        isExpanded: true,
                        dropdownColor: isDark ? DesignTokens.surfaceDark : Colors.white,
                        style: theme.textTheme.bodyMedium?.copyWith(color: inkColor),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Positions'),
                          ),
                          ...contexts.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedContextId = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'View',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ChartScope>(
                  segments: const [
                    ButtonSegment(value: ChartScope.day, label: Text('Daily')),
                    ButtonSegment(value: ChartScope.week, label: Text('Weekly')),
                    ButtonSegment(value: ChartScope.month, label: Text('Monthly')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _scope = newSelection.first;
                    });
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                    selectedForegroundColor: Colors.white,
                    foregroundColor: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<TimeEntry> entries, List<WorkContext> contexts) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    // Filter by position
    var filtered = entries;
    if (_selectedContextId != null) {
      filtered = entries.where((e) => e.contextId == _selectedContextId).toList();
    }

    // Palette colors for stacked contexts
    final palette = [
      DesignTokens.rose,
      DesignTokens.sage,
      DesignTokens.peach,
      DesignTokens.lavender,
      DesignTokens.dustyBlue,
      DesignTokens.butter,
      DesignTokens.blush,
    ];

    Color getContextColor(int contextId) {
      final ctx = contexts.firstWhereOrNull((c) => c.id == contextId);
      if (ctx?.color != null) {
        final parsedColor = int.tryParse(ctx!.color!);
        if (parsedColor != null) return Color(parsedColor);
      }
      final index = contexts.indexWhere((c) => c.id == contextId);
      final raw = palette[index >= 0 ? index % palette.length : 0];
      return isDark ? DesignTokens.adjustColorForDark(raw) : raw;
    }

    // Two-pass aggregation to ensure correct background rod sizing
    final List<_ChartDataPoint> dataPoints = [];
    double maxVal = 8.0;
    double rodWidth = 16.0;

    if (_scope == ChartScope.day) {
      maxVal = 8.0;
      rodWidth = 16.0;
      for (int i = 0; i < 7; i++) {
        final day = _currentWeekStart.add(Duration(days: i));
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        final dayEntries = filtered.where((e) => e.date == dayStr).toList();

        double accumulated = 0.0;
        final List<BarChartRodStackItem> stackItems = [];
        final groupedByCtx = groupBy(dayEntries, (TimeEntry e) => e.contextId);

        groupedByCtx.forEach((ctxId, ctxEntries) {
          final hours = ctxEntries.fold<int>(0, (sum, e) => sum + e.minutes) / 60.0;
          if (hours > 0) {
            stackItems.add(
              BarChartRodStackItem(
                accumulated,
                accumulated + hours,
                getContextColor(ctxId),
              ),
            );
            accumulated += hours;
          }
        });

        if (accumulated > maxVal) maxVal = accumulated;
        dataPoints.add(_ChartDataPoint(i, accumulated, stackItems));
      }
    } else if (_scope == ChartScope.week) {
      maxVal = 40.0;
      rodWidth = 22.0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentMon = today.subtract(Duration(days: today.weekday - 1));
      final weekStarts = List.generate(6, (i) => currentMon.subtract(Duration(days: (5 - i) * 7)));

      for (int i = 0; i < 6; i++) {
        final wStart = weekStarts[i];
        final wEnd = wStart.add(const Duration(days: 6));

        final wEntries = filtered.where((e) {
          final date = DateTime.tryParse(e.date);
          if (date == null) return false;
          final dateDayOnly = DateTime(date.year, date.month, date.day);
          return (dateDayOnly.isAtSameMomentAs(wStart) || dateDayOnly.isAfter(wStart)) &&
              (dateDayOnly.isAtSameMomentAs(wEnd) || dateDayOnly.isBefore(wEnd));
        }).toList();

        double accumulated = 0.0;
        final List<BarChartRodStackItem> stackItems = [];
        final groupedByCtx = groupBy(wEntries, (TimeEntry e) => e.contextId);

        groupedByCtx.forEach((ctxId, ctxEntries) {
          final hours = ctxEntries.fold<int>(0, (sum, e) => sum + e.minutes) / 60.0;
          if (hours > 0) {
            stackItems.add(
              BarChartRodStackItem(
                accumulated,
                accumulated + hours,
                getContextColor(ctxId),
              ),
            );
            accumulated += hours;
          }
        });

        if (accumulated > maxVal) maxVal = accumulated;
        dataPoints.add(_ChartDataPoint(i, accumulated, stackItems));
      }
    } else {
      maxVal = 160.0;
      rodWidth = 14.0;
      final yearStr = '${_currentYearStart.year}-';
      for (int i = 0; i < 12; i++) {
        final prefix = '$yearStr${(i + 1).toString().padLeft(2, '0')}-';
        final mEntries = filtered.where((e) => e.date.startsWith(prefix)).toList();

        double accumulated = 0.0;
        final List<BarChartRodStackItem> stackItems = [];
        final groupedByCtx = groupBy(mEntries, (TimeEntry e) => e.contextId);

        groupedByCtx.forEach((ctxId, ctxEntries) {
          final hours = ctxEntries.fold<int>(0, (sum, e) => sum + e.minutes) / 60.0;
          if (hours > 0) {
            stackItems.add(
              BarChartRodStackItem(
                accumulated,
                accumulated + hours,
                getContextColor(ctxId),
              ),
            );
            accumulated += hours;
          }
        });

        if (accumulated > maxVal) maxVal = accumulated;
        dataPoints.add(_ChartDataPoint(i, accumulated, stackItems));
      }
    }

    final barGroups = dataPoints.map((dp) {
      return BarChartGroupData(
        x: dp.x,
        barRods: [
          BarChartRodData(
            toY: dp.total,
            width: rodWidth,
            borderRadius: BorderRadius.circular(4),
            rodStackItems: dp.stackItems,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal,
              color: isDark ? DesignTokens.surfaceDark : Colors.grey.shade100,
            ),
          ),
        ],
      );
    }).toList();

    return AppCard(
      child: Column(
        children: [
          // Range Navigation Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_scope != ChartScope.week)
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prev,
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Center(
                  child: Text(
                    _getRangeText(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: inkColor,
                    ),
                  ),
                ),
              ),
              if (_scope != ChartScope.week)
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _next,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Container
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: isDark ? DesignTokens.lineDark : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          '${val.toInt()}h',
                          style: TextStyle(
                            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final style = TextStyle(
                          color: inkColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        );
                        if (_scope == ChartScope.day) {
                          const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (val >= 0 && val < 7) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(weekdayNames[val.toInt()], style: style),
                            );
                          }
                        } else if (_scope == ChartScope.week) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final currentMon = today.subtract(Duration(days: today.weekday - 1));
                          final wStart = currentMon.subtract(Duration(days: (5 - val.toInt()) * 7));
                          final label = val == 5 ? 'This W' : '${wStart.month}/${wStart.day}';
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(label, style: style),
                          );
                        } else {
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          if (val >= 0 && val < 12) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(months[val.toInt()], style: style),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? Colors.grey.shade800 : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String title = '';
                      if (_scope == ChartScope.day) {
                        final date = _currentWeekStart.add(Duration(days: group.x));
                        title = DateFormat('EEEE, MMM d').format(date);
                      } else if (_scope == ChartScope.week) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final currentMon = today.subtract(Duration(days: today.weekday - 1));
                        final wStart = currentMon.subtract(Duration(days: (5 - group.x) * 7));
                        title = 'Week of ${DateFormat('MMM d').format(wStart)}';
                      } else {
                        title = DateFormat('MMMM yyyy').format(DateTime(_currentYearStart.year, group.x + 1));
                      }

                      // Breakdown of hours per position in tooltip
                      final total = rod.toY;
                      if (total == 0) return null;

                      final List<TextSpan> spans = [
                        TextSpan(
                          text: '$title\n',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                      ];

                      // Fetch actual entries to show breakdowns in tooltip
                      // Since we are rebuilding list, it's easier to list positions from stackItems
                      if (rod.rodStackItems.isNotEmpty) {
                        for (final item in rod.rodStackItems) {
                          final hours = item.toY - item.fromY;
                          if (hours > 0) {
                            // Find corresponding context name
                            final matchingColor = item.color;
                            final ctx = contexts.firstWhereOrNull((c) {
                              return matchingColor != null && getContextColor(c.id) == matchingColor;
                            });
                            final ctxName = ctx?.name ?? 'Job';
                            spans.add(
                              TextSpan(
                                text: '• $ctxName: ${hours.toStringAsFixed(1)}h\n',
                                style: TextStyle(color: inkColor, fontSize: 12),
                              ),
                            );
                          }
                        }
                      } else {
                        final activeCtx = contexts.firstWhereOrNull((c) => c.id == _selectedContextId);
                        final name = activeCtx?.name ?? 'Work';
                        spans.add(
                          TextSpan(
                            text: '• $name: ${total.toStringAsFixed(1)}h\n',
                            style: TextStyle(color: inkColor, fontSize: 12),
                          ),
                        );
                      }

                      spans.add(
                        TextSpan(
                          text: 'Total: ${total.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                          ),
                        ),
                      );

                      return BarTooltipItem(
                        '',
                        theme.textTheme.bodyMedium!,
                        children: spans,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Custom Legend
          if (_selectedContextId == null)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: contexts.map((c) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: getContextColor(c.id),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      c.name,
                      style: theme.textTheme.bodySmall?.copyWith(color: inkColor),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(List<TimeEntry> entries, List<WorkContext> contexts) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    // Filter logs
    var filtered = entries;
    if (_selectedContextId != null) {
      filtered = entries.where((e) => e.contextId == _selectedContextId).toList();
    }

    double totalHours = 0.0;
    double averageHours = 0.0;
    String averageLabel = '';

    if (_scope == ChartScope.day) {
      // Calculate total in target week
      final end = _currentWeekStart.add(const Duration(days: 6));
      final weekEntries = filtered.where((e) {
        final date = DateTime.tryParse(e.date);
        if (date == null) return false;
        final dateDayOnly = DateTime(date.year, date.month, date.day);
        return (dateDayOnly.isAtSameMomentAs(_currentWeekStart) || dateDayOnly.isAfter(_currentWeekStart)) &&
            (dateDayOnly.isAtSameMomentAs(end) || dateDayOnly.isBefore(end));
      }).toList();

      totalHours = weekEntries.fold<int>(0, (sum, e) => sum + e.minutes) / 60.0;
      averageHours = totalHours / 7.0;
      averageLabel = 'Daily Average';
    } else if (_scope == ChartScope.week) {
      // Calculate total in last 6 weeks
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentMon = today.subtract(Duration(days: today.weekday - 1));
      final startLimit = currentMon.subtract(const Duration(days: 5 * 7));
      final endLimit = currentMon.add(const Duration(days: 6));

      final activeEntries = filtered.where((e) {
        final date = DateTime.tryParse(e.date);
        if (date == null) return false;
        final dateDayOnly = DateTime(date.year, date.month, date.day);
        return (dateDayOnly.isAtSameMomentAs(startLimit) || dateDayOnly.isAfter(startLimit)) &&
            (dateDayOnly.isAtSameMomentAs(endLimit) || dateDayOnly.isBefore(endLimit));
      }).toList();

      totalHours = activeEntries.fold<int>(0, (sum, e) => sum + e.minutes) / 60.0;
      averageHours = totalHours / 6.0;
      averageLabel = 'Weekly Average';
    } else {
      // Calculate total in current year
      final yearEntries = filtered.where((e) => e.date.startsWith('${_currentYearStart.year}-')).toList();
      totalHours = yearEntries.fold<int>(0, (sum, e) => sum + e.minutes) / 60.0;
      averageHours = totalHours / 12.0;
      averageLabel = 'Monthly Average';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary Stats',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: inkColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Hours',
                  '${totalHours.toStringAsFixed(1)}h',
                  theme,
                  isDark,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: isDark ? DesignTokens.lineDark : Colors.grey.shade200,
              ),
              Expanded(
                child: _buildStatItem(
                  averageLabel,
                  '${averageHours.toStringAsFixed(1)}h',
                  theme,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: 28,
            letterSpacing: 0,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
          ),
        ),
      ],
    );
  }
}

class _ChartDataPoint {
  _ChartDataPoint(this.x, this.total, this.stackItems);
  final int x;
  final double total;
  final List<BarChartRodStackItem> stackItems;
}
