import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/recurring_repository.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(
      StreamProvider.autoDispose(
        (r) => r.watch(recurringRepositoryProvider).watchAll(),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recurring_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showAddSheet(context, ref),
      ),
      body: listAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.repeat,
              message: 'No recurring transactions',
              hint: 'Add subscriptions, rent, salary and more.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (_, i) => _RecurringTile(item: items[i]),
          );
        },
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _RecurringAddSheet(),
      );
}

// ── Recurring item tile ───────────────────────────────────────────────────────

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.item});

  final RecurringTransaction item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(recurringRepositoryProvider);
    final isIn = item.direction == 'in';

    return AppCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isIn ? Colors.green : Colors.red).withAlpha(30),
          child: Icon(
            isIn ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIn ? Colors.green[700] : Colors.red[700],
            size: 18,
          ),
        ),
        title: Text(item.name),
        subtitle: Text('${item.category} · day ${item.dayOfMonth}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(item.amountCents),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Switch(
              value: item.active,
              onChanged: (v) => repo.setActive(item.id, active: v),
            ),
          ],
        ),
        onLongPress: () async {
          final confirmed = await ConfirmDialog.show(
            context,
            title: 'Delete recurring?',
            message: 'Remove "${item.name}"?',
          );
          if (confirmed == true) await repo.delete(item.id);
        },
      ),
    );
  }
}

// ── Add sheet ─────────────────────────────────────────────────────────────────

class _RecurringAddSheet extends ConsumerStatefulWidget {
  const _RecurringAddSheet();

  @override
  ConsumerState<_RecurringAddSheet> createState() => _RecurringAddSheetState();
}

class _RecurringAddSheetState extends ConsumerState<_RecurringAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dayCtrl = TextEditingController(text: '1');

  String _direction = 'out';
  String _category = _categories.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dayCtrl.dispose();
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
              'Add Recurring',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'out', label: Text('Expense')),
                ButtonSegment(value: 'in', label: Text('Income')),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (€)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (CurrencyFormatter.parseToCents(v) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Day of month',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 31) return '1–31';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Add')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final monthStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';

    await ref
        .read(recurringRepositoryProvider)
        .create(
          RecurringTransactionsCompanion.insert(
            name: _nameCtrl.text.trim(),
            amountCents: CurrencyFormatter.parseToCents(_amountCtrl.text)!,
            direction: _direction,
            dayOfMonth: int.parse(_dayCtrl.text),
            startMonth: monthStr,
            category: _category,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}

const _categories = [
  'rent',
  'food',
  'transport',
  'shopping',
  'income',
  'travel',
  'health',
  'entertainment',
  'subscription',
  'other',
];
