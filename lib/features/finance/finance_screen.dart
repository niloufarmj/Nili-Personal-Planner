import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/transaction_repository.dart';
import 'widgets/forecast_card.dart';
import 'widgets/quick_add_sheet.dart';
import 'widgets/transaction_tile.dart';

final _monthTransactionsProvider = StreamProvider.autoDispose
    .family<List<Transaction>, DateTime>(
      (ref, month) => ref
          .watch(transactionRepositoryProvider)
          .watchByMonth(month.year, month.month),
    );

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Charts',
            onPressed: () => context.push('/finance/charts', extra: _month),
          ),
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'Recurring',
            onPressed: () => context.push('/finance/recurring'),
          ),
          IconButton(
            icon: const Icon(Icons.handshake_outlined),
            tooltip: 'Debts',
            onPressed: () => context.push('/finance/debts'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'finance_fab',
        child: const Icon(Icons.add),
        onPressed: () => QuickAddSheet.show(context),
      ),
      body: Column(
        children: [
          // ── Month selector ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                ),
                Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _MonthView(month: _month)),
        ],
      ),
    );
  }
}

// ── Month view ─────────────────────────────────────────────────────────────────

class _MonthView extends ConsumerWidget {
  const _MonthView({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_monthTransactionsProvider(month));

    return txAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (transactions) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverToBoxAdapter(child: ForecastCard(month: month)),
          ),
          if (transactions.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.receipt_long,
                message: 'No transactions',
                hint: 'Tap + to add income or expenses.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate(
                _buildGroupedList(context, transactions),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedList(
    BuildContext context,
    List<Transaction> transactions,
  ) {
    final grouped = <String, List<Transaction>>{};
    for (final tx in transactions) {
      grouped.putIfAbsent(tx.date, () => []).add(tx);
    }

    final result = <Widget>[];
    for (final entry in grouped.entries) {
      result.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: SectionHeader(title: _formatDate(entry.key)),
        ),
      );
      for (final tx in entry.value) {
        result.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: TransactionTile(transaction: tx),
          ),
        );
      }
    }
    result.add(const SizedBox(height: 80));
    return result;
  }

  static String _formatDate(String iso) {
    final p = iso.split('-');
    final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return DateFormat('EEEE, MMM d').format(d);
  }
}
