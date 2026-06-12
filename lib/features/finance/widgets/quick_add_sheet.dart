import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/design.dart';
import '../repositories/transaction_repository.dart';

const _categories = [
  'food',
  'transport',
  'rent',
  'shopping',
  'income',
  'travel',
  'health',
  'entertainment',
  'other',
];

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({this.initialDate, super.key});

  final String? initialDate;

  static Future<void> show(BuildContext context, {String? initialDate}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => QuickAddSheet(initialDate: initialDate),
      );

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _direction = 'out';
  String _category = 'food';
  String _status = 'actual';
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate != null
        ? _parseDate(widget.initialDate!)
        : DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Transaction',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // ── Direction toggle ─────────────────────────────────────────
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'out', label: Text('Expense')),
                ButtonSegment(value: 'in', label: Text('Income')),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            const SizedBox(height: 12),
            // ── Amount ───────────────────────────────────────────────────
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (€)',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (CurrencyFormatter.parseToCents(v) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // ── Category ─────────────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c[0].toUpperCase() + c.substring(1)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // ── Note ─────────────────────────────────────────────────────
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // ── Status ───────────────────────────────────────────────────
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'actual', label: Text('Actual')),
                ButtonSegment(value: 'planned', label: Text('Planned')),
              ],
              selected: {_status},
              onSelectionChanged: (v) => setState(() => _status = v.first),
            ),
            // ── Date (only for planned) ──────────────────────────────────
            if (_status == 'planned') ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_fmtDate(_date)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Add')),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = CurrencyFormatter.parseToCents(_amountCtrl.text)!;
    await ref
        .read(transactionRepositoryProvider)
        .create(
          TransactionsCompanion.insert(
            date: _fmtDate(_date),
            amountCents: cents,
            direction: _direction,
            status: _status,
            category: _category,
            note: Value(
              _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
