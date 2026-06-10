import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/event_repository.dart';
import '../../core/design/design.dart';

/// Bottom sheet for creating or editing a calendar event.
class EventEditSheet extends ConsumerStatefulWidget {
  const EventEditSheet({super.key, this.existing, this.initialDate});

  final Event? existing;
  final String? initialDate; // YYYY-MM-DD pre-fill

  static Future<void> show(
    BuildContext context, {
    Event? existing,
    String? initialDate,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        EventEditSheet(existing: existing, initialDate: initialDate),
  );

  @override
  ConsumerState<EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends ConsumerState<EventEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;
  late String _category;
  late String _owner;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _weeklyRepeat = false;
  String? _repeatEndDate;

  static const _categories = [
    'social',
    'appointment',
    'partner',
    'uni',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _date = e != null
        ? _parseDate(e.date)
        : (widget.initialDate != null
              ? _parseDate(widget.initialDate!)
              : DateTime.now());
    _category = e?.category ?? 'social';
    _owner = e?.owner ?? 'me';
    if (e?.startTime != null) {
      final parts = e!.startTime!.split(':');
      _startTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    if (e?.endTime != null) {
      final parts = e!.endTime!.split(':');
      _endTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    _weeklyRepeat = e?.rrule?.contains('FREQ=WEEKLY') ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit Event' : 'New Event',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
                onTap: _pickDate,
              ),
              // Time range
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Start',
                      value: _startTime,
                      onPick: (t) => setState(() => _startTime = t),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'End',
                      value: _endTime,
                      onPick: (t) => setState(() => _endTime = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              const SectionHeader(
                title: 'Category',
                padding: EdgeInsets.only(bottom: 8),
              ),
              Wrap(
                spacing: 8,
                children: _categories.map((cat) {
                  return ChoiceChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const SectionHeader(
                title: 'Owner',
                padding: EdgeInsets.only(bottom: 8),
              ),
              Wrap(
                spacing: 8,
                children: ['me', 'partner'].map((o) {
                  return ChoiceChip(
                    label: Text(o),
                    selected: _owner == o,
                    onSelected: (_) => setState(() => _owner = o),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Weekly repeat shortcut
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat weekly'),
                value: _weeklyRepeat,
                onChanged: (v) => setState(() => _weeklyRepeat = v),
              ),
              if (_weeklyRepeat) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_repeat),
                  title: Text(
                    _repeatEndDate != null
                        ? 'Ends $_repeatEndDate'
                        : 'No end date',
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: _pickRepeatEnd,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: Text(isEdit ? 'Save' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickRepeatEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.add(const Duration(days: 90)),
      firstDate: _date,
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(
        () => _repeatEndDate =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}',
      );
    }
  }

  String? _buildRrule() {
    if (!_weeklyRepeat) return null;
    final dow = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'][_date.weekday - 1];
    final base = 'FREQ=WEEKLY;BYDAY=$dow';
    if (_repeatEndDate != null) {
      final until = _repeatEndDate!.replaceAll('-', '');
      return '$base;UNTIL=${until}T000000Z';
    }
    return base;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final dateStr =
        '${_date.year.toString().padLeft(4, '0')}-'
        '${_date.month.toString().padLeft(2, '0')}-'
        '${_date.day.toString().padLeft(2, '0')}';
    final repo = ref.read(eventRepositoryProvider);
    final companion = EventsCompanion(
      title: Value(title),
      date: Value(dateStr),
      startTime: Value(
        _startTime != null
            ? '${_startTime!.hour.toString().padLeft(2, '0')}:'
                  '${_startTime!.minute.toString().padLeft(2, '0')}'
            : null,
      ),
      endTime: Value(
        _endTime != null
            ? '${_endTime!.hour.toString().padLeft(2, '0')}:'
                  '${_endTime!.minute.toString().padLeft(2, '0')}'
            : null,
      ),
      location: Value(
        _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      ),
      category: Value(_category),
      rrule: Value(_buildRrule()),
      notes: Value(
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
      owner: Value(_owner),
    );
    if (widget.existing != null) {
      await repo.updateEvent(
        widget.existing!.copyWith(
          title: title,
          date: dateStr,
          startTime: Value(companion.startTime.value),
          endTime: Value(companion.endTime.value),
          location: Value(companion.location.value),
          category: _category,
          rrule: Value(_buildRrule()),
          notes: Value(companion.notes.value),
          owner: _owner,
        ),
      );
    } else {
      await repo.createEvent(companion);
    }
    if (mounted) Navigator.of(context).pop();
  }

  static DateTime _parseDate(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.access_time, size: 16),
      label: Text(
        value != null ? value!.format(context) : label,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        onPick(picked);
      },
    );
  }
}
