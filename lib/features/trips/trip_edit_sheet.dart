import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import 'trip_repository.dart';

/// Modal sheet for creating or editing a trip.
class TripEditSheet extends ConsumerStatefulWidget {
  const TripEditSheet({super.key, this.existing});

  final Trip? existing;

  static Future<void> show(BuildContext context, {Trip? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TripEditSheet(existing: existing),
    );
  }

  @override
  ConsumerState<TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends ConsumerState<TripEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _budget;
  late String _status;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _title = TextEditingController(text: t?.title ?? '');
    _location = TextEditingController(text: t?.location ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _budget = TextEditingController(
      text: t?.budgetCents != null
          ? (t!.budgetCents! / 100).toStringAsFixed(2)
          : '',
    );
    _status = t?.status ?? 'probable';
    _startDate = t?.startDate != null ? _parseDate(t!.startDate!) : null;
    _endDate = t?.endDate != null ? _parseDate(t!.endDate!) : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
              isEdit ? 'Edit Trip' : 'New Trip',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _StatusDropdown(
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 12),
            _DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              onChanged: (s, e) => setState(() {
                _startDate = s;
                _endDate = e;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budget,
              decoration: const InputDecoration(
                labelText: 'Budget (€)',
                prefixText: '€ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Create trip'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(tripRepositoryProvider);
    final budgetCents = _budget.text.trim().isNotEmpty
        ? (double.tryParse(_budget.text.trim()) ?? 0) * 100
        : null;

    if (widget.existing == null) {
      await repo.createTrip(
        title: _title.text.trim(),
        status: _status,
        startDate: _startDate != null ? _fmt(_startDate!) : null,
        endDate: _endDate != null ? _fmt(_endDate!) : null,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        budgetCents: budgetCents?.round(),
      );
    } else {
      final t = widget.existing!;
      await repo.updateTrip(
        t.copyWith(
          title: _title.text.trim(),
          status: _status,
          startDate: Value(_startDate != null ? _fmt(_startDate!) : null),
          endDate: Value(_endDate != null ? _fmt(_endDate!) : null),
          location: Value(
            _location.text.trim().isEmpty ? null : _location.text.trim(),
          ),
          description: Value(
            _description.text.trim().isEmpty ? null : _description.text.trim(),
          ),
          budgetCents: Value(budgetCents?.round()),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  static DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Status'),
      items: const [
        DropdownMenuItem(value: 'probable', child: Text('Probable')),
        DropdownMenuItem(value: 'final', child: Text('Final')),
        DropdownMenuItem(value: 'done', child: Text('Done')),
        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
      ],
      onChanged: (v) => onChanged(v!),
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  const _DateRangePicker({
    required this.startDate,
    required this.endDate,
    required this.onChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime?, DateTime?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: 'Start date',
            date: startDate,
            onPick: (d) => onChanged(d, endDate),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateField(
            label: 'End date',
            date: endDate,
            onPick: (d) => onChanged(startDate, d),
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
                    '${date!.month.toString().padLeft(2, '0')}/'
                    '${date!.year}'
              : 'Pick date',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
