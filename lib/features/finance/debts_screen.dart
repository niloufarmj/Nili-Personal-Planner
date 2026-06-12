import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/debt_repository.dart';

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
                onPressed: () => repo.settle(debt.id),
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
}

// ── Add sheet ─────────────────────────────────────────────────────────────────

class _DebtAddSheet extends ConsumerStatefulWidget {
  const _DebtAddSheet();

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
            Text('Add Debt', style: Theme.of(context).textTheme.titleMedium),
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
            FilledButton(onPressed: _submit, child: const Text('Add')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(debtRepositoryProvider)
        .create(
          DebtsCompanion.insert(
            person: _personCtrl.text.trim(),
            amountCents: CurrencyFormatter.parseToCents(_amountCtrl.text)!,
            direction: _direction,
            note: Value(
              _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}
