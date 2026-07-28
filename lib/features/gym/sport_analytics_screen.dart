import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'sport_repository.dart';

enum SportChartScope { day, week, month }

class SportAnalyticsScreen extends ConsumerStatefulWidget {
  const SportAnalyticsScreen({super.key});

  @override
  ConsumerState<SportAnalyticsScreen> createState() => _SportAnalyticsScreenState();
}

class _SportAnalyticsScreenState extends ConsumerState<SportAnalyticsScreen> {
  String? _selectedActivityType; // null means 'All Sports'
  SportChartScope _scope = SportChartScope.day;

  // Navigation states
  late DateTime _currentWeekStart; // Monday of target week (date-only)
  late DateTime _currentYearStart; // January 1st of target year

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
      if (_scope == SportChartScope.day) {
        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      } else if (_scope == SportChartScope.month) {
        _currentYearStart = DateTime(_currentYearStart.year + 1);
      }
    });
  }

  void _prev() {
    setState(() {
      if (_scope == SportChartScope.day) {
        _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      } else if (_scope == SportChartScope.month) {
        _currentYearStart = DateTime(_currentYearStart.year - 1);
      }
    });
  }

  String _getRangeText() {
    if (_scope == SportChartScope.day) {
      final end = _currentWeekStart.add(const Duration(days: 6));
      final fmt = DateFormat('MMM d');
      return '${fmt.format(_currentWeekStart)} – ${fmt.format(end)}, ${_currentWeekStart.year}';
    } else if (_scope == SportChartScope.week) {
      return 'Last 6 Weeks';
    } else {
      return 'Year ${_currentYearStart.year}';
    }
  }

  static const Map<String, Color> _activityColors = {
    'Gym': DesignTokens.dustyBlue,
    'Swimming': DesignTokens.sage,
    'Tennis': DesignTokens.butter,
    'Biking': DesignTokens.blush,
    'Running': DesignTokens.rose,
    'Walking': DesignTokens.peach,
    'Yoga': DesignTokens.lavender,
    'Pilates': DesignTokens.accentLight,
    'Other': Colors.grey,
  };

  Color _getActivityColor(String type, bool isDark) {
    final raw = _activityColors[type] ?? Colors.grey;
    return isDark ? DesignTokens.adjustColorForDark(raw) : raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    final activitiesAsync = ref.watch(sportActivitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sport & Fitness Analytics',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: inkColor,
          ),
        ),
      ),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (activities) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              // Filters Card
              _buildFiltersCard(activities, isDark, theme),
              const SizedBox(height: 16),

              // Chart Card
              _buildChartCard(activities, isDark, theme),
              const SizedBox(height: 16),

              // Stats Card
              _buildStatsCard(activities, isDark, theme),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersCard(List<SportActivity> activities, bool isDark, ThemeData theme) {
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final availableTypes = activities.map((a) => a.activityType).toSet().toList();
    if (!availableTypes.contains('Gym')) availableTypes.add('Gym');
    if (!availableTypes.contains('Swimming')) availableTypes.add('Swimming');
    if (!availableTypes.contains('Running')) availableTypes.add('Running');

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
                      'Activity Filter',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedActivityType,
                        isExpanded: true,
                        dropdownColor: isDark ? DesignTokens.surfaceDark : Colors.white,
                        style: theme.textTheme.bodyMedium?.copyWith(color: inkColor),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Sports'),
                          ),
                          ...availableTypes.map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedActivityType = val;
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
                'View Scope',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<SportChartScope>(
                  segments: const [
                    ButtonSegment(value: SportChartScope.day, label: Text('Daily')),
                    ButtonSegment(value: SportChartScope.week, label: Text('Weekly')),
                    ButtonSegment(value: SportChartScope.month, label: Text('Monthly')),
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

  Widget _buildChartCard(List<SportActivity> activities, bool isDark, ThemeData theme) {
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    var filtered = activities;
    if (_selectedActivityType != null) {
      filtered = activities.where((a) => a.activityType == _selectedActivityType).toList();
    }

    final List<_SportChartDataPoint> dataPoints = [];
    double maxVal = 2.0; // hours
    double rodWidth = 16.0;

    if (_scope == SportChartScope.day) {
      maxVal = 2.0;
      rodWidth = 16.0;
      for (int i = 0; i < 7; i++) {
        final day = _currentWeekStart.add(Duration(days: i));
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        final dayEntries = filtered.where((a) => a.date == dayStr).toList();

        double accumulated = 0.0;
        final List<BarChartRodStackItem> stackItems = [];
        final groupedByType = groupBy(dayEntries, (SportActivity a) => a.activityType);

        groupedByType.forEach((type, typeEntries) {
          final hours = typeEntries.fold<int>(0, (sum, a) => sum + a.durationMin) / 60.0;
          if (hours > 0) {
            stackItems.add(
              BarChartRodStackItem(
                accumulated,
                accumulated + hours,
                _getActivityColor(type, isDark),
              ),
            );
            accumulated += hours;
          }
        });

        if (accumulated > maxVal) maxVal = accumulated;
        dataPoints.add(_SportChartDataPoint(i, accumulated, stackItems));
      }
    } else if (_scope == SportChartScope.week) {
      maxVal = 8.0;
      rodWidth = 22.0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentMon = today.subtract(Duration(days: today.weekday - 1));
      final weekStarts = List.generate(6, (i) => currentMon.subtract(Duration(days: (5 - i) * 7)));

      for (int i = 0; i < 6; i++) {
        final wStart = weekStarts[i];
        final wEnd = wStart.add(const Duration(days: 6));

        final wEntries = filtered.where((a) {
          final date = DateTime.tryParse(a.date);
          if (date == null) return false;
          final dateDayOnly = DateTime(date.year, date.month, date.day);
          return (dateDayOnly.isAtSameMomentAs(wStart) || dateDayOnly.isAfter(wStart)) &&
              (dateDayOnly.isAtSameMomentAs(wEnd) || dateDayOnly.isBefore(wEnd));
        }).toList();

        double accumulated = 0.0;
        final List<BarChartRodStackItem> stackItems = [];
        final groupedByType = groupBy(wEntries, (SportActivity a) => a.activityType);

        groupedByType.forEach((type, typeEntries) {
          final hours = typeEntries.fold<int>(0, (sum, a) => sum + a.durationMin) / 60.0;
          if (hours > 0) {
            stackItems.add(
              BarChartRodStackItem(
                accumulated,
                accumulated + hours,
                _getActivityColor(type, isDark),
              ),
            );
            accumulated += hours;
          }
        });

        if (accumulated > maxVal) maxVal = accumulated;
        dataPoints.add(_SportChartDataPoint(i, accumulated, stackItems));
      }
    } else {
      maxVal = 20.0;
      rodWidth = 14.0;
      final yearStr = '${_currentYearStart.year}-';
      for (int i = 0; i < 12; i++) {
        final prefix = '$yearStr${(i + 1).toString().padLeft(2, '0')}-';
        final mEntries = filtered.where((a) => a.date.startsWith(prefix)).toList();

        double accumulated = 0.0;
        final List<BarChartRodStackItem> stackItems = [];
        final groupedByType = groupBy(mEntries, (SportActivity a) => a.activityType);

        groupedByType.forEach((type, typeEntries) {
          final hours = typeEntries.fold<int>(0, (sum, a) => sum + a.durationMin) / 60.0;
          if (hours > 0) {
            stackItems.add(
              BarChartRodStackItem(
                accumulated,
                accumulated + hours,
                _getActivityColor(type, isDark),
              ),
            );
            accumulated += hours;
          }
        });

        if (accumulated > maxVal) maxVal = accumulated;
        dataPoints.add(_SportChartDataPoint(i, accumulated, stackItems));
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
              if (_scope != SportChartScope.week)
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
              if (_scope != SportChartScope.week)
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
                          '${val.toStringAsFixed(1)}h',
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
                        if (_scope == SportChartScope.day) {
                          const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (val >= 0 && val < 7) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(weekdayNames[val.toInt()], style: style),
                            );
                          }
                        } else if (_scope == SportChartScope.week) {
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
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Custom Legend
          if (_selectedActivityType == null)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _activityColors.keys.map((type) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getActivityColor(type, isDark),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      type,
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

  Widget _buildStatsCard(List<SportActivity> activities, bool isDark, ThemeData theme) {
    var filtered = activities;
    if (_selectedActivityType != null) {
      filtered = activities.where((a) => a.activityType == _selectedActivityType).toList();
    }

    double totalHours = 0.0;
    int totalSessions = filtered.length;
    double avgDurationMin = 0.0;

    if (_scope == SportChartScope.day) {
      final end = _currentWeekStart.add(const Duration(days: 6));
      final weekEntries = filtered.where((a) {
        final date = DateTime.tryParse(a.date);
        if (date == null) return false;
        final dateDayOnly = DateTime(date.year, date.month, date.day);
        return (dateDayOnly.isAtSameMomentAs(_currentWeekStart) || dateDayOnly.isAfter(_currentWeekStart)) &&
            (dateDayOnly.isAtSameMomentAs(end) || dateDayOnly.isBefore(end));
      }).toList();

      final totalMin = weekEntries.fold<int>(0, (sum, a) => sum + a.durationMin);
      totalHours = totalMin / 60.0;
      totalSessions = weekEntries.length;
      avgDurationMin = totalSessions > 0 ? totalMin / totalSessions : 0.0;
    } else if (_scope == SportChartScope.week) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentMon = today.subtract(Duration(days: today.weekday - 1));
      final startLimit = currentMon.subtract(const Duration(days: 5 * 7));
      final endLimit = currentMon.add(const Duration(days: 6));

      final activeEntries = filtered.where((a) {
        final date = DateTime.tryParse(a.date);
        if (date == null) return false;
        final dateDayOnly = DateTime(date.year, date.month, date.day);
        return (dateDayOnly.isAtSameMomentAs(startLimit) || dateDayOnly.isAfter(startLimit)) &&
            (dateDayOnly.isAtSameMomentAs(endLimit) || dateDayOnly.isBefore(endLimit));
      }).toList();

      final totalMin = activeEntries.fold<int>(0, (sum, a) => sum + a.durationMin);
      totalHours = totalMin / 60.0;
      totalSessions = activeEntries.length;
      avgDurationMin = totalSessions > 0 ? totalMin / totalSessions : 0.0;
    } else {
      final yearEntries = filtered.where((a) => a.date.startsWith('${_currentYearStart.year}-')).toList();
      final totalMin = yearEntries.fold<int>(0, (sum, a) => sum + a.durationMin);
      totalHours = totalMin / 60.0;
      totalSessions = yearEntries.length;
      avgDurationMin = totalSessions > 0 ? totalMin / totalSessions : 0.0;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary Stats',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Sport Hours', '${totalHours.toStringAsFixed(1)}h', theme, isDark),
              ),
              Container(
                height: 40,
                width: 1,
                color: isDark ? DesignTokens.lineDark : Colors.grey.shade200,
              ),
              Expanded(
                child: _buildStatItem('Sessions', '$totalSessions', theme, isDark),
              ),
              Container(
                height: 40,
                width: 1,
                color: isDark ? DesignTokens.lineDark : Colors.grey.shade200,
              ),
              Expanded(
                child: _buildStatItem('Avg Duration', '${avgDurationMin.toStringAsFixed(0)} min', theme, isDark),
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
          style: GoogleFonts.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
          ),
        ),
      ],
    );
  }
}

class _SportChartDataPoint {
  _SportChartDataPoint(this.x, this.total, this.stackItems);
  final int x;
  final double total;
  final List<BarChartRodStackItem> stackItems;
}
