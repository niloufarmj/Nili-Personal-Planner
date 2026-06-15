import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
      loading: () => const AppCard(
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Column(
            children: [
              Center(child: ShimmerSkeleton(width: 180, height: 16)),
              SizedBox(height: 12),
              Center(child: ShimmerSkeleton(width: 140, height: 36)),
              SizedBox(height: 16),
              Divider(height: 1),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerSkeleton(width: 80, height: 14),
                  ShimmerSkeleton(width: 60, height: 14),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerSkeleton(width: 80, height: 14),
                  ShimmerSkeleton(width: 60, height: 14),
                ],
              ),
            ],
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final balance = result.estimatedEndBalanceCents;
    final balanceColor = balance >= 0
        ? (isDark ? DesignTokens.success.withValues(alpha: 0.9) : DesignTokens.success)
        : (isDark ? DesignTokens.danger.withValues(alpha: 0.9) : DesignTokens.danger);

    final greenColor = isDark ? DesignTokens.success.withValues(alpha: 0.9) : DesignTokens.success;
    final redColor = isDark ? DesignTokens.danger.withValues(alpha: 0.9) : DesignTokens.danger;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'Est. End-of-Month',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(balance),
                    style: GoogleFonts.fraunces(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _Row(
              label: 'Actual in',
              value: result.actualInCents,
              color: greenColor,
            ),
            _Row(
              label: 'Actual out',
              value: -result.actualOutCents,
              color: redColor,
            ),
            if (result.projectedRemainingOutCents > 0 ||
                result.projectedRemainingInCents > 0) ...[
              const SizedBox(height: 4),
              _Row(
                label: 'Projected in',
                value: result.projectedRemainingInCents,
                color: isDark ? DesignTokens.success.withValues(alpha: 0.6) : DesignTokens.success.withValues(alpha: 0.8),
              ),
              _Row(
                label: 'Projected out',
                value: -result.projectedRemainingOutCents,
                color: isDark ? DesignTokens.danger.withValues(alpha: 0.6) : DesignTokens.danger.withValues(alpha: 0.8),
              ),
            ],
            if (result.plannedOutCents > 0 || result.plannedInCents > 0) ...[
              const SizedBox(height: 4),
              _Row(
                label: 'Planned in',
                value: result.plannedInCents,
                color: isDark ? DesignTokens.dustyBlue.withValues(alpha: 0.8) : DesignTokens.dustyBlue,
              ),
              _Row(
                label: 'Planned out',
                value: -result.plannedOutCents,
                color: isDark ? DesignTokens.peach.withValues(alpha: 0.8) : DesignTokens.peach,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
            ),
          ),
          Text(
            CurrencyFormatter.format(value.abs()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
