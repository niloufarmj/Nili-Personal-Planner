import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import 'reminder_repository.dart';

class ReminderEditSheet extends ConsumerStatefulWidget {
  const ReminderEditSheet({super.key, this.existing});
  final Reminder? existing;

  static Future<void> show(BuildContext context, {Reminder? existing}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ReminderEditSheet(existing: existing),
      );

  @override
  ConsumerState<ReminderEditSheet> createState() => _State();
}

class _State extends ConsumerState<ReminderEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  DateTime? _windowStart;
  DateTime? _windowEnd;
  late int _priority;
  bool _notifyOnStart = false;
  int _everyNDays = 0;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _title = TextEditingController(text: r?.title ?? '');
    _description = TextEditingController(text: r?.description ?? '');
    _windowStart = r?.windowStart != null ? _parse(r!.windowStart) : null;
    _windowEnd = r?.windowEnd != null ? _parse(r!.windowEnd!) : null;
    _priority = r?.priority ?? 2;
    final rule = r?.notifyRule;
    _notifyOnStart = rule?['on_window_start'] == true;
    _everyNDays = (rule?['every_n_days'] as int?) ?? 0;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New Reminder' : 'Edit Reminder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _PriorityRow(
              value: _priority,
              onChanged: (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Window start *',
                    date: _windowStart,
                    onPick: (d) => setState(() => _windowStart = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Window end',
                    date: _windowEnd,
                    onPick: (d) => setState(() => _windowEnd = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify on window start'),
              value: _notifyOnStart,
              onChanged: (v) => setState(() => _notifyOnStart = v ?? false),
            ),
            Row(
              children: [
                const Text('Repeat every'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    initialValue: _everyNDays > 0 ? '$_everyNDays' : '',
                    decoration: const InputDecoration(hintText: '0'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        setState(() => _everyNDays = int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('days (0 = off)'),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_windowStart == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Window start is required')));
      return;
    }
    final repo = ref.read(reminderRepositoryProvider);
    final rule = <String, dynamic>{};
    if (_notifyOnStart) rule['on_window_start'] = true;
    if (_everyNDays > 0) rule['every_n_days'] = _everyNDays;

    final notifyRule = rule.isNotEmpty ? rule : null;

    if (widget.existing == null) {
      await repo.create(
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        windowStart: _fmt(_windowStart!),
        windowEnd: _windowEnd != null ? _fmt(_windowEnd!) : null,
        priority: _priority,
        notifyRule: notifyRule,
      );
    } else {
      await repo.update(
        widget.existing!.copyWith(
          title: _title.text.trim(),
          description: Value(
            _description.text.trim().isEmpty ? null : _description.text.trim(),
          ),
          windowStart: _fmt(_windowStart!),
          windowEnd: Value(_windowEnd != null ? _fmt(_windowEnd!) : null),
          priority: _priority,
          notifyRule: Value(notifyRule),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  static DateTime _parse(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Priority:'),
        const SizedBox(width: 12),
        for (final (label, v) in [('High', 1), ('Normal', 2), ('Low', 3)])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: value == v,
              onSelected: (_) => onChanged(v),
            ),
          ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onPick,
  });
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          date != null
              ? '${date!.day.toString().padLeft(2, '0')}/'
                    '${date!.month.toString().padLeft(2, '0')}/${date!.year}'
              : 'Pick date',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
