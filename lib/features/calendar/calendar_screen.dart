import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/calendar/calendar_aggregator.dart';
import '../../core/calendar/calendar_day_data.dart';
import '../../core/design/design.dart';
import 'day_detail_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _calendarFilterProvider =
    StateNotifierProvider<_FilterNotifier, CalendarFilter>(
      (_) => _FilterNotifier(),
    );

class _FilterNotifier extends StateNotifier<CalendarFilter> {
  _FilterNotifier() : super(CalendarFilter.all) {
    _load();
  }

  static const _key = 'calendar_filter_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final bits = prefs.getInt(_key);
    if (bits != null) state = _fromBits(bits);
  }

  Future<void> toggle(String field) async {
    state = switch (field) {
      'location' => state.copyWith(showLocation: !state.showLocation),
      'gym' => state.copyWith(showGym: !state.showGym),
      'meals' => state.copyWith(showMeals: !state.showMeals),
      'work' => state.copyWith(showWork: !state.showWork),
      'uni' => state.copyWith(showUni: !state.showUni),
      'travel' => state.copyWith(showTravel: !state.showTravel),
      'social' => state.copyWith(showSocial: !state.showSocial),
      'tasks' => state.copyWith(showTasks: !state.showTasks),
      'partner' => state.copyWith(showPartner: !state.showPartner),
      'reminders' => state.copyWith(showReminders: !state.showReminders),
      _ => state,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _toBits(state));
  }

  static int _toBits(CalendarFilter f) =>
      (f.showLocation ? 1 : 0) |
      (f.showGym ? 2 : 0) |
      (f.showMeals ? 4 : 0) |
      (f.showWork ? 8 : 0) |
      (f.showUni ? 16 : 0) |
      (f.showTravel ? 32 : 0) |
      (f.showSocial ? 64 : 0) |
      (f.showTasks ? 128 : 0) |
      (f.showPartner ? 256 : 0) |
      (f.showReminders ? 512 : 0);

  static CalendarFilter _fromBits(int b) => CalendarFilter(
    showLocation: b & 1 != 0,
    showGym: b & 2 != 0,
    showMeals: b & 4 != 0,
    showWork: b & 8 != 0,
    showUni: b & 16 != 0,
    showTravel: b & 32 != 0,
    showSocial: b & 64 != 0,
    showTasks: b & 128 != 0,
    showPartner: b & 256 != 0,
    showReminders: b & 512 != 0,
  );
}

final _calendarDataProvider = FutureProvider.autoDispose
    .family<Map<String, CalendarDayData>, _AggKey>((ref, key) {
      final agg = ref.watch(calendarAggregatorProvider);
      return agg.getDataForRange(key.start, key.end, filter: key.filter);
    });

class _AggKey {
  const _AggKey({required this.start, required this.end, required this.filter});
  final DateTime start;
  final DateTime end;
  final CalendarFilter filter;

  @override
  bool operator ==(Object other) =>
      other is _AggKey &&
      other.start == start &&
      other.end == end &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(start, end, filter);
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  DateTime get _windowStart =>
      DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
  DateTime get _windowEnd =>
      DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_calendarFilterProvider);
    final key = _AggKey(start: _windowStart, end: _windowEnd, filter: filter);
    final dataAsync = ref.watch(_calendarDataProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          dataAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => const SizedBox(height: 2),
            data: (_) => const SizedBox(height: 2),
          ),
          _CustomCalendarHeader(
            focusedDay: _focusedDay,
            onLeftChevronTap: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
            },
            onRightChevronTap: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
          ),
          const _HorizontalFilterBar(),
          const SizedBox(height: 8),
          Expanded(
            child: dataAsync.when(
              loading: () => _buildCalendar(context, {}),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) => _buildCalendar(context, data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    Map<String, CalendarDayData> data,
  ) {
    return TableCalendar<CalendarDayData>(
      firstDay: DateTime(2020),
      lastDay: DateTime(2040),
      focusedDay: _focusedDay,
      headerVisible: false, // hidden in favor of our custom header
      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
        final dateStr = _fmt(selected);
        DayDetailScreen.show(context, dateStr);
      },
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      calendarStyle: const CalendarStyle(outsideDaysVisible: false),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (ctx, day, _) => _DayCell(
          day: day,
          dayData: data[_fmt(day)],
          isSelected: false,
          isToday: false,
        ),
        todayBuilder: (ctx, day, _) => _DayCell(
          day: day,
          dayData: data[_fmt(day)],
          isSelected: false,
          isToday: true,
        ),
        selectedBuilder: (ctx, day, _) => _DayCell(
          day: day,
          dayData: data[_fmt(day)],
          isSelected: true,
          isToday: isSameDay(day, DateTime.now()),
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Custom Month Header ────────────────────────────────────────────────────────

class _CustomCalendarHeader extends StatelessWidget {
  const _CustomCalendarHeader({
    required this.focusedDay,
    required this.onLeftChevronTap,
    required this.onRightChevronTap,
  });

  final DateTime focusedDay;
  final VoidCallback onLeftChevronTap;
  final VoidCallback onRightChevronTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final monthStr = DateFormat('MMMM yyyy').format(focusedDay);
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final btnBg = isDark ? DesignTokens.surfaceDark : DesignTokens.lineLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            monthStr,
            style: GoogleFonts.fraunces(
              fontSize: DesignTokens.fontTitle,
              fontWeight: FontWeight.w600,
              color: inkColor,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onLeftChevronTap,
                icon: Icon(Icons.chevron_left, color: inkColor, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: btnBg,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(40, 40),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRightChevronTap,
                icon: Icon(Icons.chevron_right, color: inkColor, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: btnBg,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Horizontal Filter Bar ──────────────────────────────────────────────────────

class _HorizontalFilterBar extends ConsumerWidget {
  const _HorizontalFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_calendarFilterProvider);
    final notifier = ref.read(_calendarFilterProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      (label: 'Location', active: filter.showLocation, key: 'location', color: DesignTokens.butter, icon: Icons.map_outlined),
      (label: 'Gym', active: filter.showGym, key: 'gym', color: DesignTokens.dustyBlue, icon: Icons.fitness_center),
      (label: 'Meals', active: filter.showMeals, key: 'meals', color: DesignTokens.peach, icon: Icons.restaurant),
      (label: 'Work', active: filter.showWork, key: 'work', color: DesignTokens.lavender, icon: Icons.work_outline),
      (label: 'Uni', active: filter.showUni, key: 'uni', color: DesignTokens.sage, icon: Icons.school_outlined),
      (label: 'Travel', active: filter.showTravel, key: 'travel', color: DesignTokens.sage, icon: Icons.flight),
      (label: 'Social', active: filter.showSocial, key: 'social', color: DesignTokens.rose, icon: Icons.event),
      (label: 'Tasks', active: filter.showTasks, key: 'tasks', color: DesignTokens.lavender, icon: Icons.task_alt),
      (label: 'Partner', active: filter.showPartner, key: 'partner', color: DesignTokens.dustyBlueSoft, icon: Icons.favorite_border),
      (label: 'Reminders', active: filter.showReminders, key: 'reminders', color: DesignTokens.roseSoft, icon: Icons.notifications_none),
    ];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final fg = isDark ? DesignTokens.inkDark : item.color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(item.icon, size: 14, color: item.active ? (isDark ? DesignTokens.paperDark : Colors.white) : fg),
              label: Text(item.label),
              selected: item.active,
              selectedColor: isDark ? DesignTokens.accentDark : item.color,
              checkmarkColor: isDark ? DesignTokens.paperDark : Colors.white,
              backgroundColor: Colors.transparent,
              side: BorderSide(
                color: item.active ? Colors.transparent : (isDark ? DesignTokens.lineDark : DesignTokens.lineLight),
                width: 1,
              ),
              labelStyle: TextStyle(
                color: item.active 
                    ? (isDark ? DesignTokens.paperDark : Colors.white)
                    : (isDark ? DesignTokens.inkDark : DesignTokens.inkLight),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              onSelected: (_) => notifier.toggle(item.key),
            ),
          );
        },
      ),
    );
  }
}

// ── Day Cell ───────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    this.dayData,
  });

  final DateTime day;
  final CalendarDayData? dayData;
  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = isDark ? DesignTokens.accentDark : DesignTokens.accentLight;
    final lineColor = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    final overlay = dayData?.overlayColor;

    final border = isToday
        ? Border.all(color: accentColor, width: 1.5)
        : Border.all(color: lineColor.withAlpha(50), width: 0.5);

    final Color? selectColor = isSelected
        ? accentColor.withValues(alpha: 0.12)
        : null;

    final List<Color> washColors = [];
    if (overlay != null) {
      washColors.add(overlay);
    }
    if (dayData?.gymSession != null) {
      washColors.add(DesignTokens.dustyBlue);
    }
    if (dayData != null && dayData!.mealDots > 0) {
      washColors.add(DesignTokens.peach);
    }
    if (dayData != null && dayData!.dueDots > 0) {
      washColors.add(DesignTokens.lavender);
    }

    // Trip continuous capsule behind number
    final trip = dayData?.tripBars.firstOrNull;
    Widget? tripBarWidget;
    if (trip != null) {
      final tripStart = _parseDate(trip.startDate!);
      final tripEnd = _parseDate(trip.endDate!);
      
      final isStart = isSameDay(day, tripStart) || day.weekday == DateTime.monday;
      final isEnd = isSameDay(day, tripEnd) || day.weekday == DateTime.sunday;

      final BorderRadius radius;
      if (isStart && isEnd) {
        radius = BorderRadius.circular(8);
      } else if (isStart) {
        radius = const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8));
      } else if (isEnd) {
        radius = const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8));
      } else {
        radius = BorderRadius.zero;
      }

      tripBarWidget = Positioned(
        bottom: 8,
        left: isStart ? 4 : 0,
        right: isEnd ? 4 : 0,
        height: 6,
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? DesignTokens.adjustColorForDark(DesignTokens.sage) : DesignTokens.sage).withValues(alpha: 0.40),
            borderRadius: radius,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(color: selectColor)
              : DayWashDecoration(tagColors: washColors, isDark: isDark),
          child: Stack(
            children: [
              if (tripBarWidget != null) tripBarWidget,

              // Partner Strip Dotted line at top
              if (dayData != null && (dayData!.partnerTags.isNotEmpty || dayData!.partnerEvents.isNotEmpty))
                Positioned(
                  top: 3,
                  left: 4,
                  right: 4,
                  height: 3,
                  child: CustomPaint(
                    painter: DottedLinePainter(
                      color: isDark ? DesignTokens.adjustColorForDark(DesignTokens.dustyBlueSoft) : DesignTokens.dustyBlue,
                    ),
                  ),
                ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: inkColor,
                        fontWeight: isToday || isSelected ? FontWeight.bold : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (dayData != null && !dayData!.isEmpty) _DotRow(dayData: dayData!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

class DottedLinePainter extends CustomPainter {
  DottedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double startX = 2.0;
    const double dashWidth = 2.0;
    const double dashSpace = 3.0;

    while (startX < size.width - 2) {
      canvas.drawCircle(Offset(startX, 1.0), 1.0, paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Dots Row ──────────────────────────────────────────────────────────────────

class _DotRow extends StatelessWidget {
  const _DotRow({required this.dayData});
  final CalendarDayData dayData;

  @override
  Widget build(BuildContext context) {
    final List<Color> dotColors = [];
    if (dayData.eventOccurrences.isNotEmpty) {
      dotColors.add(AppColors.catSocial);
    }
    if (dayData.tripBars.isNotEmpty) {
      dotColors.add(AppColors.travel);
    }
    if (dayData.gymSession != null) {
      dotColors.add(AppColors.catFitness);
    }
    if (dayData.mealDots > 0) {
      dotColors.add(AppColors.catMeals);
    }
    if (dayData.dueDots > 0) {
      dotColors.add(AppColors.catWork);
    }

    if (dotColors.isEmpty) return const SizedBox.shrink();

    final showOverflow = dotColors.length > 4;
    final visibleDots = dotColors.take(4).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...visibleDots.map((c) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        )),
        if (showOverflow)
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
          ),
      ],
    );
  }
}
