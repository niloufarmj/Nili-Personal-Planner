import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../nutrition_profile.dart';

class NutritionProfileSheet extends ConsumerStatefulWidget {
  const NutritionProfileSheet({this.profile, super.key});

  final NutritionProfile? profile;

  @override
  ConsumerState<NutritionProfileSheet> createState() => _NutritionProfileSheetState();
}

class _NutritionProfileSheetState extends ConsumerState<NutritionProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late String _gender;
  late FitnessGoal _goal;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _ageCtrl = TextEditingController(text: p?.age?.toString() ?? '');
    _heightCtrl = TextEditingController(text: p?.heightCm?.toString() ?? '');
    _weightCtrl = TextEditingController(text: p?.weightKg?.toString() ?? '');
    _gender = p?.gender ?? 'female';
    _goal = p?.fitnessGoal ?? FitnessGoal.lose;
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Nutrition & Goal Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Set your personal parameters for tailored daily calorie and protein suggestions.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 20),

              // Gender & Age Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'female'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age (years)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0)
                          ? 'Enter age'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Height & Weight Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                          ? 'Enter height'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                          ? 'Enter weight'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Fitness Goal
              DropdownButtonFormField<FitnessGoal>(
                value: _goal,
                decoration: const InputDecoration(
                  labelText: 'Fitness Goal',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(
                    value: FitnessGoal.lose,
                    child: Text('Weight Loss / Fat Loss'),
                  ),
                  DropdownMenuItem(
                    value: FitnessGoal.maintain,
                    child: Text('Maintain Current Weight'),
                  ),
                  DropdownMenuItem(
                    value: FitnessGoal.gain,
                    child: Text('Muscle Gain / Surplus'),
                  ),
                ],
                onChanged: (v) => setState(() => _goal = v ?? FitnessGoal.lose),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save Profile'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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

    final newProfile = NutritionProfile(
      age: int.parse(_ageCtrl.text.trim()),
      gender: _gender,
      heightCm: double.parse(_heightCtrl.text.trim()),
      weightKg: double.parse(_weightCtrl.text.trim()),
      fitnessGoal: _goal,
    );

    await ref.read(nutritionProfileRepositoryProvider).saveProfile(newProfile);
    ref.invalidate(nutritionProfileProvider);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
