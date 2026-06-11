import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/calendar/calendar_aggregator.dart';
import '../../core/calendar/calendar_day_data.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/design.dart';
import '../../core/router/routes.dart';

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

// Aggregated data for the visible month ± 1 month buffer.
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
    final key = _AggKey(
      start: _windowStart,
      end: _windowEnd,
      filter: filter,
    );
    final dataAsync = ref.watch(_calendarDataProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Filters',
            onPressed: () => _showFilterSheet(context, filter),
          ),
        ],
      ),
      body: Column(
        children: [
          dataAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => const SizedBox(height: 2),
            data: (_) => const SizedBox(height: 2),
          ),
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
      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
        final dateStr = _fmt(selected);
        context.push(Routes.dayDetail.replaceFirst(':date', dateStr));
      },
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
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

  void _showFilterSheet(BuildContext context, CalendarFilter filter) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _FilterSheet(filter: filter),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Day cell ──────────────────────────────────────────────────────────────────

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
    final cs = theme.colorScheme;
    final overlay = dayData?.overlayColor;

    Color? bgColor;
    if (isSelected) {
      bgColor = cs.primary;
    } else if (overlay != null) {
      bgColor = overlay.withAlpha(50);
    }

    final textColor = isSelected
        ? cs.onPrimary
        : isToday
        ? cs.primary
        : null;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: isToday && !isSelected
            ? Border.all(color: cs.primary, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: isToday || isSelected ? FontWeight.bold : null,
            ),
          ),
          if (dayData != null && !dayData!.isEmpty)
            _DotRow(dayData: dayData!),
        ],
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  const _DotRow({required this.dayData});
  final CalendarDayData dayData;

  @override
  Widget build(BuildContext context) {
    final dots = <Color>[
      if (dayData.eventOccurrences.isNotEmpty) AppColors.catSocial,
      if (dayData.tripBars.isNotEmpty) AppColors.travel,
      if (dayData.gymSession != null) AppColors.catFitness,
      if (dayData.mealDots > 0) AppColors.catMeals,
      if (dayData.dueDots > 0) AppColors.catWork,
    ];
    if (dots.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dots
          .take(3)
          .map(
            (c) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          )
          .toList(),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.filter});
  final CalendarFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(_calendarFilterProvider.notifier);
    final current = ref.watch(_calendarFilterProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Show on calendar',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Chip('Location', current.showLocation, () => notifier.toggle('location')),
                _Chip('Gym', current.showGym, () => notifier.toggle('gym')),
                _Chip('Meals', current.showMeals, () => notifier.toggle('meals')),
                _Chip('Work', current.showWork, () => notifier.toggle('work')),
                _Chip('Uni', current.showUni, () => notifier.toggle('uni')),
                _Chip('Travel', current.showTravel, () => notifier.toggle('travel')),
                _Chip('Social', current.showSocial, () => notifier.toggle('social')),
                _Chip('Tasks', current.showTasks, () => notifier.toggle('tasks')),
                _Chip('Partner', current.showPartner, () => notifier.toggle('partner')),
                _Chip('Reminders', current.showReminders, () => notifier.toggle('reminders')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.active, this.onTap);
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
    );
  }
}
