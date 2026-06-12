import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'gym_repository.dart';

final _allPlansProvider = StreamProvider.autoDispose<List<WorkoutPlan>>(
  (ref) => ref.watch(workoutPlanRepositoryProvider).watchAll(),
);

/// Lists all workout plans and lets the user view / edit each one.
class WorkoutPlansScreen extends ConsumerWidget {
  const WorkoutPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(_allPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Plans')),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return const EmptyState(
              icon: Icons.fitness_center,
              message: 'No plans yet',
              hint:
                  'Plans A, B and C will appear here once seeded on first launch.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _PlanCard(plan: plans[i]),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        leading: CircleAvatar(child: Text(plan.name)),
        title: Text('Plan ${plan.name}'),
        subtitle: plan.content.trim().isEmpty
            ? const Text('Empty — tap to add exercises')
            : Text(
                plan.content.trim().split('\n').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkoutPlanDetailScreen(plan: plan),
          ),
        ),
      ),
    );
  }
}

/// Full-screen view/edit for a single workout plan.
class WorkoutPlanDetailScreen extends ConsumerStatefulWidget {
  const WorkoutPlanDetailScreen({required this.plan, super.key});
  final WorkoutPlan plan;

  @override
  ConsumerState<WorkoutPlanDetailScreen> createState() =>
      _WorkoutPlanDetailScreenState();
}

class _WorkoutPlanDetailScreenState
    extends ConsumerState<WorkoutPlanDetailScreen> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.plan.content);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plan ${widget.plan.name}'),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save',
              onPressed: _save,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _editing
            ? TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Enter exercises, sets, reps…',
                  border: OutlineInputBorder(),
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              )
            : widget.plan.content.trim().isEmpty
            ? const EmptyState(
                icon: Icons.fitness_center,
                message: 'Plan is empty',
                hint: 'Tap the edit button to add your exercises.',
              )
            : SingleChildScrollView(
                child: SelectableText(
                  widget.plan.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(workoutPlanRepositoryProvider);
    await repo.update(widget.plan.copyWith(content: _ctrl.text));
    if (mounted) setState(() => _editing = false);
  }
}
