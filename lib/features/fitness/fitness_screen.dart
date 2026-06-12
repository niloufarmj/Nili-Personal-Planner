import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/services/image_service.dart';
import 'fitness_repository.dart';

// ── State for custom field definitions ────────────────────────────────────────

final _customFieldsProvider = StateNotifierProvider<CustomFieldsNotifier, List<String>>((ref) {
  return CustomFieldsNotifier();
});

class CustomFieldsNotifier extends StateNotifier<List<String>> {
  CustomFieldsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('fitness_custom_fields') ?? ['waist_cm', 'body_fat_pct'];
  }

  Future<void> addField(String name) async {
    final cleanName = name.trim().replaceAll(' ', '_').toLowerCase();
    if (cleanName.isEmpty || state.contains(cleanName)) return;
    state = [...state, cleanName];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fitness_custom_fields', state);
  }

  Future<void> removeField(String name) async {
    state = state.where((f) => f != name).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fitness_custom_fields', state);
  }
}

// ── Fitness Screen ────────────────────────────────────────────────────────────

class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_customFieldsProvider); // Trigger initial load

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fitness'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Custom Fields',
              onPressed: () => _showSettingsSheet(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Log', icon: Icon(Icons.show_chart)),
              Tab(text: 'Photos', icon: Icon(Icons.photo_library)),
              Tab(text: 'Goals', icon: Icon(Icons.flag)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MeasurementsTab(),
            _PhotosTab(),
            _GoalsTab(),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CustomFieldsSettingsSheet(),
    );
  }
}

// ── Custom fields settings sheet ───────────────────────────────────────────────

class _CustomFieldsSettingsSheet extends ConsumerStatefulWidget {
  const _CustomFieldsSettingsSheet();

  @override
  ConsumerState<_CustomFieldsSettingsSheet> createState() => _CustomFieldsSettingsSheetState();
}

class _CustomFieldsSettingsSheetState extends ConsumerState<_CustomFieldsSettingsSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = ref.watch(_customFieldsProvider);
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Custom Measurement Fields', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create fields like "chest_cm", "thigh_cm", or "body_fat_pct" to log them along with your weight.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (fields.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No custom fields defined yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: fields.map((f) {
                return Chip(
                  label: Text(f),
                  onDeleted: () => ref.read(_customFieldsProvider.notifier).removeField(f),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    labelText: 'New field name (e.g. chest_cm)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final text = _ctrl.text;
                  if (text.isNotEmpty) {
                    ref.read(_customFieldsProvider.notifier).addField(text);
                    _ctrl.clear();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final _fitnessMeasurementsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(fitnessRepositoryProvider).watchMeasurements(),
);

// ── Measurements Tab ───────────────────────────────────────────────────────────

class _MeasurementsTab extends ConsumerWidget {
  const _MeasurementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mAsync = ref.watch(_fitnessMeasurementsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'measurements_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showAddMeasurementSheet(context, ref),
      ),
      body: mAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (measurements) {
          if (measurements.isEmpty) {
            return const EmptyState(
              icon: Icons.monitor_weight_outlined,
              message: 'No logs yet',
              hint: 'Tap + to log your weight and measurements.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WeightChart(measurements: measurements),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Log History'),
              const SizedBox(height: 8),
              ...measurements.map((m) => _MeasurementCard(measurement: m)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  void _showAddMeasurementSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MeasurementAddSheet(),
    );
  }
}

// ── Weight chart ──────────────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.measurements});

  final List<Measurement> measurements;

  @override
  Widget build(BuildContext context) {
    final points = measurements.reversed
        .where((m) => m.weightKg != null)
        .toList();

    if (points.length < 2) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Add at least 2 logs to view weight trend chart.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final spots = points.indexed.map((e) {
      final (i, m) = e;
      return FlSpot(i.toDouble(), m.weightKg!);
    }).toList();

    final minW = points.map((m) => m.weightKg!).reduce((a, b) => a < b ? a : b) - 2;
    final maxW = points.map((m) => m.weightKg!).reduce((a, b) => a > b ? a : b) + 2;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight Trend (kg)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: minW,
                  maxY: maxW,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withAlpha(20),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final d = points[i].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              d.substring(5, 10),
                              style: const TextStyle(fontSize: 8),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Measurement card ──────────────────────────────────────────────────────────

class _MeasurementCard extends ConsumerWidget {
  const _MeasurementCard({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateObj = DateTime.parse(measurement.date);
    final formattedDate = DateFormat('MMMM d, yyyy').format(dateObj);

    final fields = measurement.fields ?? {};

    return AppCard(
      child: ListTile(
        title: Text(formattedDate),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (measurement.weightKg != null)
                _MeasurementChip(
                  label: '${measurement.weightKg} kg',
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ...fields.entries.map((e) {
                return _MeasurementChip(
                  label: '${e.key}: ${e.value}',
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                );
              }),
              if (measurement.photos != null && measurement.photos!.isNotEmpty)
                _MeasurementChip(
                  label: '${measurement.photos!.length} 📷',
                  backgroundColor: Colors.purple.withAlpha(30),
                  foregroundColor: Colors.purple[700] ?? Colors.purple,
                ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _confirmDelete(context, ref),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Log?',
      message: 'Remove measurement log on ${measurement.date}?',
    );
    if (confirmed == true) {
      await ref.read(fitnessRepositoryProvider).deleteMeasurement(measurement.id);
    }
  }
}

// ── Add measurement sheet ──────────────────────────────────────────────────────

class _MeasurementAddSheet extends ConsumerStatefulWidget {
  const _MeasurementAddSheet();

  @override
  ConsumerState<_MeasurementAddSheet> createState() => _MeasurementAddSheetState();
}

class _MeasurementAddSheetState extends ConsumerState<_MeasurementAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _customCtrls = <String, TextEditingController>{};
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _weightCtrl.dispose();
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customFields = ref.watch(_customFieldsProvider);
    final insets = MediaQuery.viewInsetsOf(context);

    for (final field in customFields) {
      _customCtrls.putIfAbsent(field, () => TextEditingController());
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log Measurements', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_date)}'),
              trailing: TextButton(
                onPressed: _selectDate,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                  return 'Invalid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ...customFields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _customCtrls[field],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: field.replaceAll('_', ' '),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.tryParse(_weightCtrl.text);
    final fields = <String, double>{};
    for (final entry in _customCtrls.entries) {
      final val = double.tryParse(entry.value.text);
      if (val != null) {
        fields[entry.key] = val;
      }
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    await ref.read(fitnessRepositoryProvider).createMeasurement(
      MeasurementsCompanion.insert(
        date: dateStr,
        weightKg: Value(weight),
        fields: Value(fields.isEmpty ? null : fields),
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }
}

// ── Photos Tab ─────────────────────────────────────────────────────────────────

class _PhotosTab extends ConsumerWidget {
  const _PhotosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mAsync = ref.watch(_fitnessMeasurementsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'photos_fab',
        child: const Icon(Icons.add_a_photo),
        onPressed: () => _showAddPhotoSheet(context, ref),
      ),
      body: mAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (measurements) {
          final photoList = <_PhotoItem>[];
          for (final m in measurements) {
            if (m.photos != null) {
              for (final path in m.photos!) {
                photoList.add(_PhotoItem(date: m.date, path: path, measurement: m));
              }
            }
          }

          if (photoList.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_camera_outlined,
              message: 'No photos yet',
              hint: 'Tap 📷 to attach progress photos to a date.',
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photoList.length,
            itemBuilder: (context, i) {
              final photo = photoList[i];
              return GestureDetector(
                onTap: () => _viewPhoto(context, photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _viewPhoto(BuildContext context, _PhotoItem photo) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(photo.path)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Logged on ${photo.date}'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPhotoSheet(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final imagePath = await ref.read(imageServiceProvider).pick(source: source);
    if (imagePath == null) return;
    if (!context.mounted) return;

    // Pick date to attach the photo
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(pickedDate);

    // Find if a measurement already exists on this date
    final repo = ref.read(fitnessRepositoryProvider);
    final measurements = await repo.getMeasurements();
    final match = measurements.where((m) => m.date == dateStr).firstOrNull;

    if (match != null) {
      final currentPhotos = match.photos ?? [];
      await repo.updateMeasurement(
        match.copyWith(
          photos: Value([...currentPhotos, imagePath]),
        ),
      );
    } else {
      await repo.createMeasurement(
        MeasurementsCompanion.insert(
          date: dateStr,
          photos: Value([imagePath]),
        ),
      );
    }
  }
}

class _PhotoItem {
  const _PhotoItem({required this.date, required this.path, required this.measurement});
  final String date;
  final String path;
  final Measurement measurement;
}

final _fitnessGoalsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(fitnessRepositoryProvider).watchGoals(),
);

// ── Goals Tab ──────────────────────────────────────────────────────────────────

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gAsync = ref.watch(_fitnessGoalsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'goals_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showAddGoalSheet(context, ref),
      ),
      body: gAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          if (goals.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              message: 'No fitness goals',
              hint: 'Tap + to set a new fitness or weight target.',
            );
          }

          final openGoals = goals.where((g) => g.achievedDate == null).toList();
          final achievedGoals = goals.where((g) => g.achievedDate != null).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (openGoals.isNotEmpty) ...[
                const SectionHeader(title: 'Active Goals'),
                const SizedBox(height: 8),
                ...openGoals.map((g) => _GoalCard(goal: g)),
                const SizedBox(height: 16),
              ],
              if (achievedGoals.isNotEmpty) ...[
                const SectionHeader(title: 'Achieved Goals'),
                const SizedBox(height: 8),
                ...achievedGoals.map((g) => _GoalCard(goal: g)),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GoalAddSheet(),
    );
  }
}

// ── Goal Card ─────────────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final FitnessGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAchieved = goal.achievedDate != null;

    return AppCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isAchieved ? Colors.green : Colors.blue).withAlpha(30),
          child: Icon(
            isAchieved ? Icons.emoji_events : Icons.flag,
            color: isAchieved ? Colors.green[700] : Colors.blue[700],
          ),
        ),
        title: Text(
          '${goal.metric.replaceAll('_', ' ')} target: ${goal.target}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isAchieved ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Direction: ${goal.direction == 'down' ? 'Lose/Decrease' : 'Gain/Increase'}'),
            if (goal.deadline != null) Text('Deadline: ${goal.deadline}'),
            if (isAchieved)
              Text(
                'Achieved on ${goal.achievedDate} 🏆',
                style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => ref.read(fitnessRepositoryProvider).deleteGoal(goal.id),
        ),
      ),
    );
  }
}

// ── Goal Add Sheet ────────────────────────────────────────────────────────────

class _GoalAddSheet extends ConsumerStatefulWidget {
  const _GoalAddSheet();

  @override
  ConsumerState<_GoalAddSheet> createState() => _GoalAddSheetState();
}

class _GoalAddSheetState extends ConsumerState<_GoalAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _targetCtrl = TextEditingController();
  String _metric = 'weight';
  String _direction = 'down';
  DateTime? _deadline;

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customFields = ref.watch(_customFieldsProvider);
    final insets = MediaQuery.viewInsetsOf(context);

    final metrics = ['weight', ...customFields];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Set Fitness Goal', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _metric,
              items: metrics.map((m) {
                return DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' ')));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _metric = v);
              },
              decoration: const InputDecoration(
                labelText: 'Goal Metric',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'down', label: Text('Lose/Decrease')),
                ButtonSegment(value: 'up', label: Text('Gain/Increase')),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Value',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_deadline == null ? 'No deadline' : 'Deadline: ${DateFormat('yyyy-MM-dd').format(_deadline!)}'),
              trailing: TextButton(
                onPressed: _selectDeadline,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Create Goal')),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final target = double.parse(_targetCtrl.text);
    final deadlineStr = _deadline != null ? DateFormat('yyyy-MM-dd').format(_deadline!) : null;

    await ref.read(fitnessRepositoryProvider).createGoal(
      FitnessGoalsCompanion.insert(
        metric: _metric,
        target: target,
        direction: Value(_direction),
        deadline: Value(deadlineStr),
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }
}

class _MeasurementChip extends StatelessWidget {
  const _MeasurementChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
