import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/services/image_service.dart';
import 'fitness_repository.dart';

class FitnessLogScreen extends ConsumerStatefulWidget {
  const FitnessLogScreen({super.key, this.existing});

  /// The measurement being edited, or null when logging a new entry.
  final Measurement? existing;

  @override
  ConsumerState<FitnessLogScreen> createState() => _FitnessLogScreenState();
}

class _FitnessLogScreenState extends ConsumerState<FitnessLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _hipCtrl = TextEditingController();
  final _bicepCtrl = TextEditingController();
  final _thighCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  final List<String> _photos = [];
  final List<String> _originalPhotos = [];
  final List<String> _sessionPickedPhotos = [];
  final List<String> _pendingDeletePhotos = [];
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _date = DateTime.parse(existing.date);
      _weightCtrl.text = existing.weightKg?.toString() ?? '';
      final fields = existing.fields ?? {};
      _waistCtrl.text = fields['waist_cm']?.toString() ?? '';
      _chestCtrl.text = fields['chest_cm']?.toString() ?? '';
      _hipCtrl.text = fields['hip_cm']?.toString() ?? '';
      _bicepCtrl.text = fields['bicep_cm']?.toString() ?? '';
      _thighCtrl.text = fields['thigh_cm']?.toString() ?? '';
      _photos.addAll(existing.photos ?? []);
      _originalPhotos.addAll(existing.photos ?? []);
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waistCtrl.dispose();
    _chestCtrl.dispose();
    _hipCtrl.dispose();
    _bicepCtrl.dispose();
    _thighCtrl.dispose();

    // Clean up orphaned photos if the user leaves without saving
    if (!_saved) {
      final imageService = ref.read(imageServiceProvider);
      for (final path in _sessionPickedPhotos) {
        imageService.delete(path);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Log Measurements' : 'Edit Entry'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Date Selector Card
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(_date)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectDate,
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Weight & Measurements Card
            SectionHeader(
              title: 'Body Measurements',
              trailing: Text(
                'Enter size in cm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                    validator: _validateNumber,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _waistCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Waist size (cm)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    validator: _validateNumber,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _chestCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Chest size (cm)',
                      prefixIcon: Icon(Icons.accessibility_new),
                    ),
                    validator: _validateNumber,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hipCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Hip size (cm)',
                      prefixIcon: Icon(Icons.boy),
                    ),
                    validator: _validateNumber,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bicepCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Bicep size (cm)',
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                    validator: _validateNumber,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _thighCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Thigh size (cm)',
                      prefixIcon: Icon(Icons.directions_run),
                    ),
                    validator: _validateNumber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Progress Photos Section
            const SectionHeader(title: 'Progress Photos'),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attach pictures to visually track your body composition changes over time.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ..._photos.map((path) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image(
                                image: imageProviderFor(path)!,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removePhoto(path),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      // Add Photo Button
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? DesignTokens.paperDark
                                : DesignTokens.paperLight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Photo',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                ),
              ),
              child: Text(
                'Save Entry',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String? _validateNumber(String? v) {
    if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
      return 'Invalid number';
    }
    return null;
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

  Future<void> _pickPhoto() async {
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

    setState(() {
      _photos.add(imagePath);
      _sessionPickedPhotos.add(imagePath);
    });
  }

  void _removePhoto(String path) {
    setState(() {
      _photos.remove(path);
    });
    if (_sessionPickedPhotos.remove(path)) {
      // Newly picked this session and never saved — safe to delete now.
      ref.read(imageServiceProvider).delete(path);
    } else if (_originalPhotos.contains(path)) {
      // Was part of the saved entry — only delete the file once the removal
      // is actually confirmed by saving, so cancelling leaves it intact.
      _pendingDeletePhotos.add(path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.tryParse(_weightCtrl.text);

    // Collect all cm measurements
    final fields = <String, double>{};
    final waist = double.tryParse(_waistCtrl.text);
    if (waist != null) fields['waist_cm'] = waist;
    final chest = double.tryParse(_chestCtrl.text);
    if (chest != null) fields['chest_cm'] = chest;
    final hip = double.tryParse(_hipCtrl.text);
    if (hip != null) fields['hip_cm'] = hip;
    final bicep = double.tryParse(_bicepCtrl.text);
    if (bicep != null) fields['bicep_cm'] = bicep;
    final thigh = double.tryParse(_thighCtrl.text);
    if (thigh != null) fields['thigh_cm'] = thigh;

    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    _saved = true; // Mark as saved so dispose doesn't clean up photos

    final imageService = ref.read(imageServiceProvider);
    for (final path in _pendingDeletePhotos) {
      await imageService.delete(path);
    }

    final repo = ref.read(fitnessRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repo.createMeasurement(
        MeasurementsCompanion.insert(
          date: dateStr,
          weightKg: Value(weight),
          fields: Value(fields.isEmpty ? null : fields),
          photos: Value(_photos.isEmpty ? null : _photos),
        ),
      );
    } else {
      await repo.updateMeasurement(
        existing.copyWith(
          date: dateStr,
          weightKg: Value(weight),
          fields: Value(fields.isEmpty ? null : fields),
          photos: Value(_photos.isEmpty ? null : _photos),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }
}
