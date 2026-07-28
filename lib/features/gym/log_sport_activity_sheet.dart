import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import 'gym_repository.dart';
import 'sport_repository.dart';

class LogSportActivitySheet extends ConsumerStatefulWidget {
  const LogSportActivitySheet({super.key, this.initialDate});

  final String? initialDate;

  static Future<void> show(BuildContext context, {String? initialDate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogSportActivitySheet(initialDate: initialDate),
    );
  }

  @override
  ConsumerState<LogSportActivitySheet> createState() => _LogSportActivitySheetState();
}

class _LogSportActivitySheetState extends ConsumerState<LogSportActivitySheet> {
  final _formKey = GlobalKey<FormState>();
  late String _date;
  String _activityType = 'Gym';
  int _durationMin = 45;
  int? _calories;
  String _intensity = 'Moderate';
  String _notes = '';
  int? _selectedPlanId;

  static const _activities = [
    {'type': 'Gym', 'icon': Icons.fitness_center, 'label': 'Gym Workout'},
    {'type': 'Swimming', 'icon': Icons.pool, 'label': 'Swimming'},
    {'type': 'Tennis', 'icon': Icons.sports_tennis, 'label': 'Tennis'},
    {'type': 'Biking', 'icon': Icons.directions_bike, 'label': 'Biking / Cycling'},
    {'type': 'Running', 'icon': Icons.directions_run, 'label': 'Running'},
    {'type': 'Walking', 'icon': Icons.directions_walk, 'label': 'Walking'},
    {'type': 'Yoga', 'icon': Icons.self_improvement, 'label': 'Yoga'},
    {'type': 'Pilates', 'icon': Icons.accessibility_new, 'label': 'Pilates'},
    {'type': 'Other', 'icon': Icons.sports_soccer, 'label': 'Other Sport'},
  ];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateFormat('yyyy-MM-DD').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final plansAsync = ref.watch(workoutPlanRepositoryProvider).watchAll();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? DesignTokens.lineDark : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Log Sport Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 16),

              // Activity Type Grid Selector
              Text(
                'Activity Type',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _activities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final act = _activities[idx];
                    final isSelected = act['type'] == _activityType;
                    return ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      avatar: Icon(
                        act['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : inkColor,
                      ),
                      label: Text(act['type'] as String),
                      selectedColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : inkColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _activityType = act['type'] as String;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Gym Plan Selector (If Gym activity)
              if (_activityType == 'Gym') ...[
                StreamBuilder(
                  stream: plansAsync,
                  builder: (context, snap) {
                    final plans = snap.data ?? [];
                    return DropdownButtonFormField<int?>(
                      value: _selectedPlanId,
                      decoration: const InputDecoration(
                        labelText: 'Gym Plan (Optional)',
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Custom Gym Session')),
                        ...plans.map((p) => DropdownMenuItem(value: p.id, child: Text('Plan ${p.name}'))),
                      ],
                      onChanged: (val) => setState(() => _selectedPlanId = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Duration & Calories Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _durationMin.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (min)',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      validator: (val) {
                        final v = int.tryParse(val ?? '');
                        if (v == null || v <= 0) return 'Enter minutes';
                        return null;
                      },
                      onSaved: (val) => _durationMin = int.parse(val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calories (kcal)',
                        prefixIcon: Icon(Icons.local_fire_department_outlined),
                      ),
                      onSaved: (val) {
                        if (val != null && val.isNotEmpty) {
                          _calories = int.tryParse(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Intensity Choice Chips
              Row(
                children: [
                  Text(
                    'Intensity: ',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: inkColor),
                  ),
                  const SizedBox(width: 12),
                  ...['Low', 'Moderate', 'High'].map((lvl) {
                    final isSel = _intensity == lvl;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSel,
                        label: Text(lvl),
                        selectedColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                        labelStyle: TextStyle(color: isSel ? Colors.white : inkColor),
                        onSelected: (_) => setState(() => _intensity = lvl),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Notes Input
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Notes (e.g. 500m laps, 5km run)',
                  prefixIcon: Icon(Icons.notes),
                ),
                onSaved: (val) => _notes = val ?? '',
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Save Activity'),
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final sportRepo = ref.read(sportRepositoryProvider);
    final gymRepo = ref.read(gymRepositoryProvider);

    // Log in SportActivities table
    await sportRepo.logActivity(
      date: _date,
      activityType: _activityType,
      durationMin: _durationMin,
      calories: _calories,
      intensity: _intensity,
      notes: _notes,
      gymPlanId: _selectedPlanId,
    );

    // If activity is Gym, also log in GymSessions for attendance tracking
    if (_activityType == 'Gym') {
      await gymRepo.logDone(
        date: _date,
        planId: _selectedPlanId,
        durationMin: _durationMin,
        notes: _notes,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_activityType activity logged!')),
      );
    }
  }
}
