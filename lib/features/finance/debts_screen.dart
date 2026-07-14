import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/debt_repository.dart';
import 'repositories/transaction_repository.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Unsettled'),
              Tab(text: 'Settled'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'debts_fab',
          child: const Icon(Icons.add),
          onPressed: () => _showAddSheet(context, ref),
        ),
        body: const TabBarView(
          children: [_DebtList(settled: false), _DebtList(settled: true)],
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _DebtAddSheet(),
      );
}

final _debtsStreamProvider = StreamProvider.autoDispose
    .family<List<Debt>, bool>(
      (ref, settled) => settled
          ? ref.watch(debtRepositoryProvider).watchSettled()
          : ref.watch(debtRepositoryProvider).watchAll(),
    );

// ── Debt list ─────────────────────────────────────────────────────────────────

class _DebtList extends ConsumerWidget {
  const _DebtList({required this.settled});

  final bool settled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_debtsStreamProvider(settled));

    return listAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (debts) {
        if (debts.isEmpty) {
          return EmptyState(
            icon: Icons.handshake_outlined,
            message: settled ? 'No settled debts' : 'No open debts',
            hint: 'Add debts you owe or are owed.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: debts.length,
          itemBuilder: (_, i) => _DebtTile(debt: debts[i]),
        );
      },
    );
  }
}

// ── Debt tile ─────────────────────────────────────────────────────────────────

class _DebtTile extends ConsumerWidget {
  const _DebtTile({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(debtRepositoryProvider);
    final iOwe = debt.direction == 'i_owe';

    return AppCard(
      child: ListTile(
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _DebtAddSheet(existing: debt),
          );
        },
        leading: CircleAvatar(
          backgroundColor: (iOwe ? Colors.red : Colors.green).withAlpha(30),
          child: Icon(
            iOwe ? Icons.arrow_upward : Icons.arrow_downward,
            color: iOwe ? Colors.red[700] : Colors.green[700],
            size: 18,
          ),
        ),
        title: Text(debt.person),
        subtitle: Text(iOwe ? 'I owe' : 'Owes me'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(debt.amountCents),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!debt.settled)
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                tooltip: 'Mark settled',
                onPressed: () => _handleSettle(context, ref, debt),
              ),
          ],
        ),
        onLongPress: () async {
          final confirmed = await ConfirmDialog.show(
            context,
            title: 'Delete debt?',
            message: 'Remove debt with "${debt.person}"?',
          );
          if (confirmed == true) await repo.delete(debt.id);
        },
      ),
    );
  }

  Future<void> _handleSettle(BuildContext context, WidgetRef ref, Debt debt) async {
    final amountText = CurrencyFormatter.format(debt.amountCents);
    final iOwe = debt.direction == 'i_owe';

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Debt'),
        content: Text(
          'Mark debt with "${debt.person}" as settled?\n\n'
          'Would you like to log this $amountText payment in your finances?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('settle_only'),
            child: const Text('Settle only'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('log_payment'),
            child: const Text('Log payment'),
          ),
        ],
      ),
    );

    if (choice == 'cancel' || choice == null) return;

    if (choice == 'log_payment') {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await ref.read(transactionRepositoryProvider).create(
        TransactionsCompanion.insert(
          date: todayStr,
          amountCents: debt.amountCents,
          direction: iOwe ? 'out' : 'in',
          status: 'actual',
          category: 'other',
          note: Value('Debt payoff: ${debt.person}'),
        ),
      );
    }

    await ref.read(debtRepositoryProvider).settle(debt.id);
  }
}

// ── Add sheet ─────────────────────────────────────────────────────────────────

class _DebtAddSheet extends ConsumerStatefulWidget {
  const _DebtAddSheet({this.existing});
  final Debt? existing;

  @override
  ConsumerState<_DebtAddSheet> createState() => _DebtAddSheetState();
}

class _DebtAddSheetState extends ConsumerState<_DebtAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _direction = 'i_owe';

  @override
  void initState() {
    super.initState();
    final ext = widget.existing;
    if (ext != null) {
      _personCtrl.text = ext.person;
      _amountCtrl.text = (ext.amountCents / 100.0).toStringAsFixed(2);
      _noteCtrl.text = ext.note ?? '';
      _direction = ext.direction;
    }
  }

  @override
  void dispose() {
    _personCtrl.dispose();
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
              widget.existing != null ? 'Edit Debt' : 'Add Debt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'i_owe', label: Text('I owe')),
                ButtonSegment(value: 'owes_me', label: Text('Owes me')),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _personCtrl,
              decoration: const InputDecoration(
                labelText: 'Person',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.existing != null ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(debtRepositoryProvider);
    final newAmountCents = CurrencyFormatter.parseToCents(_amountCtrl.text)!;
    final person = _personCtrl.text.trim();
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    if (widget.existing != null) {
      final ext = widget.existing!;
      final oldAmountCents = ext.amountCents;

      if (newAmountCents < oldAmountCents) {
        final diffCents = oldAmountCents - newAmountCents;
        final diffText = CurrencyFormatter.format(diffCents);

        final logPayment = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log Payment?'),
            content: Text(
              'You reduced the debt with "$person" by $diffText.\n\n'
              'Would you like to log this payment in your finances?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, log payment'),
              ),
            ],
          ),
        );

        if (logPayment == true) {
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          await ref.read(transactionRepositoryProvider).create(
            TransactionsCompanion.insert(
              date: todayStr,
              amountCents: diffCents,
              direction: ext.direction == 'i_owe' ? 'out' : 'in',
              status: 'actual',
              category: 'other',
              note: Value('Debt payment: $person'),
            ),
          );
        }
      } else if (newAmountCents > oldAmountCents) {
        final diffCents = newAmountCents - oldAmountCents;
        final diffText = CurrencyFormatter.format(diffCents);
        final iOwe = ext.direction == 'i_owe';

        final logPayment = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log Transaction?'),
            content: Text(
              iOwe
                  ? 'You increased the debt you owe to "$person" by $diffText (meaning they lent you $diffText).\n\n'
                      'Would you like to log this inflow in your finances?'
                  : 'You increased the debt "$person" owes you by $diffText (meaning you lent them $diffText).\n\n'
                      'Would you like to log this outflow in your finances?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, log payment'),
              ),
            ],
          ),
        );

        if (logPayment == true) {
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          await ref.read(transactionRepositoryProvider).create(
            TransactionsCompanion.insert(
              date: todayStr,
              amountCents: diffCents,
              direction: iOwe ? 'in' : 'out',
              status: 'actual',
              category: 'other',
              note: Value(iOwe ? 'Received loan: $person' : 'Lent money: $person'),
            ),
          );
        }
      }

      final isSettled = newAmountCents == 0;
      final updated = ext.copyWith(
        person: person,
        amountCents: newAmountCents,
        direction: _direction,
        note: Value(note),
        settled: isSettled ? true : ext.settled,
      );
      await repo.update(updated);
    } else {
      await repo.create(
        DebtsCompanion.insert(
          person: person,
          amountCents: newAmountCents,
          direction: _direction,
          note: Value(note),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
