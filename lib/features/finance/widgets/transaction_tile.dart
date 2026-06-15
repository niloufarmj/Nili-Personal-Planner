import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/design.dart';
import '../repositories/transaction_repository.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({required this.transaction, super.key});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = transaction;
    final isIn = tx.direction == 'in';
    final isPlanned = tx.status == 'planned';
    final color = isIn ? Colors.green[700] : Colors.red[700];

    return AppCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: isPlanned
            ? RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        leading: CircleAvatar(
          backgroundColor: (isIn ? Colors.green : Colors.red).withAlpha(30),
          child: Icon(
            isIn ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          tx.note ?? tx.category,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            decoration: isPlanned ? TextDecoration.none : null,
            fontStyle: isPlanned ? FontStyle.italic : null,
          ),
        ),
        subtitle: Text(
          '${tx.category}${isPlanned ? ' · planned' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIn ? '+' : '-'}${CurrencyFormatter.format(tx.amountCents)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPlanned)
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                tooltip: 'Mark as actual',
                onPressed: () => _markActual(ref, tx),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markActual(WidgetRef ref, Transaction tx) async {
    await ref
        .read(transactionRepositoryProvider)
        .update(tx.copyWith(status: 'actual'));
  }
}
