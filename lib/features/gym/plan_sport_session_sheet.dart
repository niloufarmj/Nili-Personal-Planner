import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import 'gym_repository.dart';

class PlanSportSessionSheet extends ConsumerStatefulWidget {
  const PlanSportSessionSheet({super.key, this.initialDate});

  final String? initialDate;

  static Future<void> show(BuildContext context, {String? initialDate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlanSportSessionSheet(initialDate: initialDate),
    );
  }

  @override
  ConsumerState<PlanSportSessionSheet> createState() => _PlanSportSessionSheetState();
}

class _PlanSportSessionSheetState extends ConsumerState<PlanSportSessionSheet> {
  late DateTime _selectedDate;
  String _activityType = 'Gym';
  int? _selectedPlanId;
  final _notesCtrl = TextEditingController();

  static const _activities = [
    {'type': 'Gym', 'icon': Icons.fitness_center},
    {'type': 'Swimming', 'icon': Icons.pool},
    {'type': 'Tennis', 'icon': Icons.sports_tennis},
    {'type': 'Biking', 'icon': Icons.directions_bike},
    {'type': 'Running', 'icon': Icons.directions_run},
    {'type': 'Walking', 'icon': Icons.directions_walk},
    {'type': 'Yoga', 'icon': Icons.self_improvement},
    {'type': 'Pilates', 'icon': Icons.accessibility_new},
    {'type': 'Other', 'icon': Icons.sports_soccer},
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialDate != null) {
      _selectedDate = DateTime.tryParse(widget.initialDate!) ?? now;
    } else {
      _selectedDate = now;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
              'Plan Sport / Gym Session',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 16),

            // Date Picker Row
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Target Date: ${DateFormat('EEEE, MMM d').format(_selectedDate)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change Date'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Activity Type Choice Chips
            Text(
              'Activity Type',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _activities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final act = _activities[idx];
                  final typeStr = act['type'] as String;
                  final isSelected = typeStr == _activityType;
                  return ChoiceChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(
                      act['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : inkColor,
                    ),
                    label: Text(typeStr),
                    selectedColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : inkColor,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _activityType = typeStr;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Gym Plan Picker (if Gym)
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

            // Notes / Title Input
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: _activityType == 'Gym' ? 'Notes (Optional)' : 'Session Title / Notes (Optional)',
                hintText: _activityType == 'Gym' ? 'Leg day, Heavy squats...' : 'Morning swim, 5km run...',
                prefixIcon: const Icon(Icons.notes),
              ),
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
                icon: const Icon(Icons.event_available),
                label: const Text('Schedule Session'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    final repo = ref.read(gymRepositoryProvider);
    final userNotes = _notesCtrl.text.trim();
    final noteStr = userNotes.isNotEmpty
        ? (_activityType == 'Gym' ? userNotes : '$_activityType · $userNotes')
        : (_activityType == 'Gym' ? null : '$_activityType Session');

    await repo.planSession(
      date: _dateStr,
      planId: _activityType == 'Gym' ? _selectedPlanId : null,
      notes: noteStr,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_activityType session planned for ${DateFormat('MMM d').format(_selectedDate)}!')),
      );
    }
  }
}
