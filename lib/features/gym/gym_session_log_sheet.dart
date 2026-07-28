import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'gym_repository.dart';

import 'sport_repository.dart';

// Top-level provider — stable identity, no rebuild loop.
final _allPlansProvider = StreamProvider.autoDispose<List<WorkoutPlan>>(
  (ref) => ref.watch(workoutPlanRepositoryProvider).watchAll(),
);

/// Bottom sheet: one-tap "Done today" with optional detail editing.
class GymSessionLogSheet extends ConsumerStatefulWidget {
  const GymSessionLogSheet({required this.date, this.plannedPlanId, super.key});

  final String date;
  final int? plannedPlanId;

  static Future<void> show(
    BuildContext context, {
    required String date,
    int? plannedPlanId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          GymSessionLogSheet(date: date, plannedPlanId: plannedPlanId),
    );
  }

  @override
  ConsumerState<GymSessionLogSheet> createState() => _GymSessionLogSheetState();
}

class _GymSessionLogSheetState extends ConsumerState<GymSessionLogSheet> {
  String _activityType = 'Gym';
  int? _selectedPlanId;
  int _durationMin = 60;
  int? _calories;
  final _notesCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();

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
    _selectedPlanId = widget.plannedPlanId;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _caloriesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final plansAsync = ref.watch(_allPlansProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log gym session',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(widget.date, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),

          // Activity Type Chips Selector
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

          // Plan picker (only for Gym)
          if (_activityType == 'Gym') ...[
            plansAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => const SizedBox.shrink(),
              data: (plans) => DropdownButtonFormField<int?>(
                decoration: const InputDecoration(labelText: 'Plan (optional)'),
                initialValue: _selectedPlanId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('No plan')),
                  ...plans.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('Plan ${p.name}'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedPlanId = v),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Duration
          Row(
            children: [
              Expanded(
                child: Text(
                  'Duration: $_durationMin min',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _durationMin > 15
                    ? () => setState(() => _durationMin -= 15)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _durationMin += 15),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Calories (optional)
          TextField(
            controller: _caloriesCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Calories burned (optional)',
              hintText: 'e.g. 350',
            ),
          ),
          const SizedBox(height: 8),

          // Notes
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'How did it go?',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Mark done'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final calories = int.tryParse(_caloriesCtrl.text.trim());

    // 1. Log in SportActivities for analytics
    final sportRepo = ref.read(sportRepositoryProvider);
    await sportRepo.logActivity(
      date: widget.date,
      activityType: _activityType,
      durationMin: _durationMin,
      calories: calories,
      notes: notes,
      gymPlanId: _activityType == 'Gym' ? _selectedPlanId : null,
    );

    // 2. If activity is Gym, also log in GymSessions for attendance
    if (_activityType == 'Gym') {
      final gymRepo = ref.read(gymRepositoryProvider);
      await gymRepo.logDone(
        date: widget.date,
        planId: _selectedPlanId,
        durationMin: _durationMin,
        notes: notes,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }
}

// ── Plan selector chip row (for quick plan picking from Gym screen) ────────────

class PlanSelectorRow extends ConsumerWidget {
  const PlanSelectorRow({
    required this.selectedId,
    required this.onSelect,
    super.key,
  });

  final int? selectedId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(_allPlansProvider);

    return plansAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (plans) => Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Any'),
            selected: selectedId == null,
            onSelected: (_) => onSelect(null),
          ),
          ...plans.map(
            (p) => ChoiceChip(
              label: Text('Plan ${p.name}'),
              selected: selectedId == p.id,
              onSelected: (_) => onSelect(p.id),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan viewer widget (read-only markdown-like display) ─────────────────────

class WorkoutPlanViewer extends ConsumerWidget {
  const WorkoutPlanViewer({required this.planId, super.key});
  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(workoutPlanRepositoryProvider);
    return FutureBuilder<WorkoutPlan>(
      future: repo.get(planId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return const Text('Plan not found');
        }
        final plan = snap.data!;
        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan ${plan.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                plan.content.trim().isEmpty
                    ? Text(
                        'No content yet — edit this plan to add exercises.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      )
                    : SelectableText(
                        plan.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.6,
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
