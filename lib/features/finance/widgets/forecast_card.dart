import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../models/forecast_result.dart';
import '../services/forecast_service.dart';

final _forecastFamilyProvider = FutureProvider.autoDispose
    .family<ForecastResult, DateTime>(
      (ref, month) => ref.watch(forecastServiceProvider).computeForMonth(month),
    );

class ForecastCard extends ConsumerWidget {
  const ForecastCard({required this.month, super.key});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(_forecastFamilyProvider(month));

    return forecastAsync.when(
      loading: () =>
          const AppCard(child: LinearProgressIndicator(minHeight: 2)),
      error: (e, _) => AppCard(child: Text('Forecast error: $e')),
      data: (result) => _ForecastCardData(result: result),
    );
  }
}

class _ForecastCardData extends StatelessWidget {
  const _ForecastCardData({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final balance = result.estimatedEndBalanceCents;
    final balanceColor = balance >= 0 ? Colors.green[700] : Colors.red[700];

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Est. End-of-Month', style: tt.titleSmall),
                Text(
                  CurrencyFormatter.format(balance),
                  style: tt.titleLarge?.copyWith(
                    color: balanceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _Row(
              label: 'Actual in',
              value: result.actualInCents,
              color: Colors.green[700],
            ),
            _Row(
              label: 'Actual out',
              value: -result.actualOutCents,
              color: Colors.red[700],
            ),
            if (result.projectedRemainingOutCents > 0 ||
                result.projectedRemainingInCents > 0) ...[
              const SizedBox(height: 4),
              _Row(
                label: 'Projected in',
                value: result.projectedRemainingInCents,
                color: Colors.green[400],
              ),
              _Row(
                label: 'Projected out',
                value: -result.projectedRemainingOutCents,
                color: Colors.red[400],
              ),
            ],
            if (result.plannedOutCents > 0 || result.plannedInCents > 0) ...[
              const SizedBox(height: 4),
              _Row(
                label: 'Planned in',
                value: result.plannedInCents,
                color: Colors.blue[400],
              ),
              _Row(
                label: 'Planned out',
                value: -result.plannedOutCents,
                color: Colors.orange[400],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            CurrencyFormatter.format(value.abs()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
