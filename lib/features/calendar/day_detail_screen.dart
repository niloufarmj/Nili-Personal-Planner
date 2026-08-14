import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/calendar/calendar_aggregator.dart';
import '../../core/db/database.dart';
import '../../core/db/repositories/event_repository.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';
import '../finance/repositories/transaction_repository.dart';
import '../finance/widgets/transaction_tile.dart';
import '../gym/gym_screen.dart';
import '../lists/repositories/item_repository.dart';
import '../meals/meal_slot_repository.dart';
import '../period/period_screen.dart';
import '../period/services/period_service.dart';
import 'day_tag_picker.dart';
import 'event_edit_sheet.dart';
import '../lists/widgets/task_edit_sheet.dart';

class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({required this.date, super.key});

  final String date; // YYYY-MM-DD

  static void show(BuildContext context, String date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _DayDetailSheetContent(
          date: date,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scaffold fallback for direct link routing
    return Scaffold(body: _DayDetailSheetContent(date: date));
  }
}

// ── Sheet Content ─────────────────────────────────────────────────────────────

class _DayDetailSheetContent extends ConsumerWidget {
  const _DayDetailSheetContent({required this.date, this.scrollController});

  final String date;
  final ScrollController? scrollController;

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final parsed = _parseDate(date);
    final headerFmt = DateFormat('EEEE, MMMM d, yyyy');

    final tagsAsync = ref.watch(dayTagsFutureProvider(date));
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
        child: Column(
          children: [
            // ── DayWash Header + Drag Handle ──
            tagsAsync.when(
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(height: 140),
              data: (tags) {
                final washColors = tags
                    .map((t) => AppColors.forTagName(t.name))
                    .toList();
                return Container(
                  width: double.infinity,
                  decoration: DayWashDecoration(
                    tagColors: washColors,
                    isDark: isDark,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              headerFmt.format(parsed),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: inkColor,
                              ),
                            ),
                          ),
                          FloatingActionButton.small(
                            heroTag: 'day_detail_fab_$date',
                            backgroundColor: isDark
                                ? DesignTokens.accentDark
                                : DesignTokens.accentLight,
                            foregroundColor: Colors.white,
                            onPressed: () =>
                                EventEditSheet.show(context, initialDate: date),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Sections List ──
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 88),
                children: [
                  // Tags Editor
                  const SectionHeader(title: 'Tags Catalog'),
                  const SizedBox(height: 8),
                  DayTagPicker(date: date),
                  const SizedBox(height: 24),

                  // Quick Actions Bar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, size: 16),
                          label: const Text('+ Event'),
                          onPressed: () => EventEditSheet.show(context, initialDate: date),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check_box_outlined, size: 16),
                          label: const Text('+ Task'),
                          onPressed: () => TaskEditSheet.show(context, initialDate: date),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Events
                  const SectionHeader(title: 'Scheduled Events'),
                  _EventsSection(date: date),
                  const SizedBox(height: 24),

                  // Finance
                  const SectionHeader(title: 'Finance (Planned & Forecast)'),
                  _FinanceSection(date: date),
                  const SizedBox(height: 24),

                  // Meals
                  const SectionHeader(title: 'Meals Menu'),
                  _MealsSection(date: date),
                  const SizedBox(height: 24),

                  // Cycle & Period
                  const SectionHeader(title: 'Cycle & Period Tracker'),
                  _PeriodSection(date: date),
                  const SizedBox(height: 24),

                  // Gym
                  const SectionHeader(title: 'Fitness & Gym Session'),
                  DayDetailGymSection(date: date),
                  const SizedBox(height: 24),

                  // Due items
                  const SectionHeader(title: 'Chore Deadlines & Tasks'),
                  _DueItemsSection(date: date),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day Tags Future Provider ──
final dayTagsFutureProvider = FutureProvider.autoDispose
    .family<List<Tag>, String>((ref, date) {
      return ref.watch(dayRepositoryProvider).getTagsForDate(date);
    });

// ── Custom Flat List Tile Widget (Left Category-Colored Bar) ──────────────────

class FlatListTile extends StatelessWidget {
  const FlatListTile({
    required this.title,
    required this.categoryColor,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Color categoryColor;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight;
    final lineColor = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: BorderSide(color: categoryColor, width: 5),
          top: BorderSide(color: lineColor, width: 1),
          right: BorderSide(color: lineColor, width: 1),
          bottom: BorderSide(color: lineColor, width: 1),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: ListTileTheme(
        textColor: inkColor,
        iconColor: inkColor,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: leading,
          title: DefaultTextStyle.merge(
            style: TextStyle(color: inkColor),
            child: title,
          ),
          subtitle: subtitle != null
              ? DefaultTextStyle.merge(
                  style: TextStyle(color: softInk),
                  child: subtitle!,
                )
              : null,
          trailing: trailing,
        ),
      ),
    );
  }
}

// ── Events section ─────────────────────────────────────────────────────────────

final _eventsForDateStreamProvider = StreamProvider.autoDispose
    .family<List<EventOccurrence>, String>(
      (ref, dateStr) {
        final p = dateStr.split('-');
        final day = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        return ref.watch(eventRepositoryProvider).watchOccurrencesForRange(day, day);
      },
    );

class _EventsSection extends ConsumerWidget {
  const _EventsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final occAsync = ref.watch(_eventsForDateStreamProvider(date));

    return occAsync.when(
      loading: () => const SizedBox(
        height: 20,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Error loading events: $e'),
      data: (occs) {
        if (occs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No events today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: occs.map((occ) {
            final e = occ.event;
            final timeStr = e.startTime != null
                ? '${e.startTime}${e.endTime != null ? ' – ${e.endTime}' : ''}'
                : null;

            final catColor = AppColors.forTagName(e.category);
            final badgeBg = DesignTokens.resolvePastelFill(
              color: catColor,
              isDark: isDark,
            );
            final badgeFg = isDark ? DesignTokens.inkDark : catColor;
            final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
            final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;
            final cardBg = isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight;
            final border = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  border: Border.all(color: border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: catColor, width: 4),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: Category Pill + Time + Owner
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                e.category.toUpperCase(),
                                style: TextStyle(
                                  color: badgeFg,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (timeStr != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.access_time, size: 12, color: softInk),
                              const SizedBox(width: 3),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: softInk,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (e.owner != 'me')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: DesignTokens.peach.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  e.owner.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: DesignTokens.peach,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title + Edit/Delete
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                e.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: inkColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => EventEditSheet.show(context, existing: e),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: DesignTokens.danger,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () async {
                                final ok = await ConfirmDialog.show(
                                  context,
                                  title: 'Delete Event?',
                                  message: 'Remove "${e.title}" from your schedule?',
                                );
                                if (ok == true) {
                                  await ref.read(eventRepositoryProvider).deleteEvent(e.id);
                                  ref.invalidate(calendarAggregatorProvider);
                                }
                              },
                            ),
                          ],
                        ),

                        if (e.location != null || (e.notes != null && e.notes!.isNotEmpty)) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (e.location != null) ...[
                                Icon(Icons.place_outlined, size: 13, color: softInk),
                                const SizedBox(width: 3),
                                Text(
                                  e.location!,
                                  style: TextStyle(fontSize: 12, color: softInk),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (e.notes != null && e.notes!.isNotEmpty) ...[
                                Icon(Icons.notes, size: 13, color: softInk),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    e.notes!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: softInk),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Finance section ────────────────────────────────────────────────────────────

class _FinanceSection extends ConsumerWidget {
  const _FinanceSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_transactionsForDateFutureProvider(date));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return txAsync.when(
      loading: () => const SizedBox(
        height: 20,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (txs) {
        if (txs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No transactions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: txs.map((tx) {
            final formattedAmount = CurrencyFormatter.format(tx.amountCents);
            final sign = tx.direction == 'in' ? '+' : '–';
            final color = tx.direction == 'in'
                ? DesignTokens.success
                : DesignTokens.danger;

            final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
            final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

            return FlatListTile(
              categoryColor: DesignTokens.sage,
              title: Text(
                tx.note ?? tx.category,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: inkColor,
                ),
              ),
              subtitle: Text(tx.category, style: TextStyle(color: softInk)),
              trailing: Text(
                '$sign$formattedAmount',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Meals Section ─────────────────────────────────────────────────────────────

class _MealsSection extends ConsumerWidget {
  const _MealsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealSlotsAsync = ref.watch(_mealsForDateStreamProvider(date));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return mealSlotsAsync.when(
      loading: () => const SizedBox(
        height: 20,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (slots) {
        if (slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No meals planned today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return FutureBuilder<List<Recipe>>(
          future: ref
              .read(appDatabaseProvider)
              .select(ref.read(appDatabaseProvider).recipes)
              .get(),
          builder: (context, snapshot) {
            final recipes = snapshot.data ?? [];
            final recipeMap = {for (final r in recipes) r.id: r};

            final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
            final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;
            final cardBg = isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight;
            final border = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;

            return Column(
              children: slots.map((slot) {
                final recipe = slot.recipeId != null
                    ? recipeMap[slot.recipeId]
                    : null;
                final recipeName = recipe?.name ?? 'No recipe planned';

                final slotIcon = switch (slot.slot.toLowerCase()) {
                  'breakfast' => Icons.free_breakfast_outlined,
                  'lunch' => Icons.lunch_dining_outlined,
                  'dinner' => Icons.dinner_dining_outlined,
                  _ => Icons.restaurant_outlined,
                };

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                      border: Border.all(color: border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: DesignTokens.peach, width: 4),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(slotIcon, color: DesignTokens.peach, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${slot.slot.substring(0, 1).toUpperCase()}${slot.slot.substring(1)}: $recipeName',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: inkColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Status: ${slot.status.toUpperCase()}',
                                    style: TextStyle(color: softInk, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (slot.status == 'accepted')
                              TextButton(
                                onPressed: () => ref
                                    .read(mealSlotRepositoryProvider)
                                    .updateStatus(slot.date, slot.slot, 'eaten'),
                                child: const Text('Mark Eaten'),
                              )
                            else if (slot.status == 'eaten')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: DesignTokens.sageSoft,
                                  borderRadius: BorderRadius.all(Radius.circular(4)),
                                ),
                                child: const Text(
                                  '✓ Eaten',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: DesignTokens.sage,
                                  ),
                                ),
                              )
                            else
                              TextButton(
                                onPressed: () => context.push('/meals'),
                                child: const Text('Plan Meal'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

// ── Due Items Section ──────────────────────────────────────────────────────────

class _DueItemsSection extends ConsumerWidget {
  const _DueItemsSection({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_itemsForDateStreamProvider(date));
    final theme = Theme.of(context);

    return itemsAsync.when(
      loading: () => const SizedBox(
        height: 20,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'No items due today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        final isDark = theme.brightness == Brightness.dark;
        final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
        final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;
        final cardBg = isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight;
        final border = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;

        return Column(
          children: items.map((item) {
            final isCompleted = item.status == 'done';
            final prioLabel = switch (item.priority) {
              1 => 'HIGH',
              3 => 'LOW',
              _ => 'NORMAL',
            };
            final prioColor = switch (item.priority) {
              1 => DesignTokens.danger,
              3 => DesignTokens.dustyBlue,
              _ => DesignTokens.sage,
            };

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  border: Border.all(color: border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: DesignTokens.lavender, width: 4),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isCompleted,
                          activeColor: DesignTokens.accentLight,
                          onChanged: (val) {
                            ref
                                .read(itemRepositoryProvider)
                                .toggleItemStatus(
                                  item.id,
                                  doneStatus: 'done',
                                  openStatus: 'open',
                                );
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isCompleted ? softInk : inkColor,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: prioColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      prioLabel,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: prioColor,
                                      ),
                                    ),
                                  ),
                                  if (item.dueDate != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.calendar_today, size: 11, color: softInk),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.dueDate!,
                                      style: TextStyle(fontSize: 11, color: softInk),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: softInk, size: 20),
                          onPressed: () =>
                              context.push('/collection/${item.collectionId}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

final _transactionsForDateFutureProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>(
      (ref, date) => ref.watch(transactionRepositoryProvider).getByDate(date),
    );

final _mealsForDateStreamProvider = StreamProvider.autoDispose
    .family<List<MealSlot>, String>((ref, date) {
      final db = ref.watch(appDatabaseProvider);
      return (db.select(
        db.mealSlots,
      )..where((s) => s.date.equals(date))).watch();
    });

final _itemsForDateStreamProvider = StreamProvider.autoDispose
    .family<List<Item>, String>((ref, date) {
      final db = ref.watch(appDatabaseProvider);
      return (db.select(
        db.items,
      )..where((i) => i.dueDate.equals(date))).watch();
    });

// ── Period Section ─────────────────────────────────────────────────────────────

class _PeriodSection extends ConsumerWidget {
  const _PeriodSection({required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final actualPeriods = ref.watch(actualPeriodDatesProvider);
    final predictedPeriods = ref.watch(predictedPeriodDatesProvider).value ?? {};
    final ovulationDates = ref.watch(predictedOvulationDatesProvider).value ?? {};

    final isActual = actualPeriods.contains(date);
    final isPredicted = predictedPeriods.contains(date);
    final isOvulation = ovulationDates.contains(date);

    if (isActual) {
      return AppCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: const CircleAvatar(
            backgroundColor: DesignTokens.rose,
            child: Icon(Icons.water_drop, color: Colors.white, size: 20),
          ),
          title: const Text('Period Day (Logged)', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Logged cycle day. Tap to view tracker.'),
          trailing: FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PeriodScreen()),
            ),
            child: const Text('View'),
          ),
        ),
      );
    }

    if (isPredicted) {
      return AppCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: DesignTokens.roseSoft,
            child: const Icon(Icons.water_drop_outlined, color: DesignTokens.rose, size: 20),
          ),
          title: const Text('Estimated Period Day 🌸', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Predicted period phase based on your average cycle.'),
          trailing: FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Started Today'),
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.rose,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final dateObj = DateTime.parse(date);
              await ref.read(periodServiceProvider).logPeriodStartToday(dateObj);
              ref.invalidate(periodLogsStreamProvider);
              ref.invalidate(actualPeriodDatesProvider);
              ref.invalidate(predictedPeriodDatesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Period start logged!')),
                );
              }
            },
          ),
        ),
      );
    }

    if (isOvulation) {
      return AppCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: const CircleAvatar(
            backgroundColor: DesignTokens.dustyBlueSoft,
            child: Icon(Icons.egg_outlined, color: DesignTokens.dustyBlue, size: 20),
          ),
          title: const Text('Estimated Ovulation Day 🥚', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Predicted fertile window.'),
          trailing: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PeriodScreen()),
            ),
            child: const Text('View Cycle'),
          ),
        ),
      );
    }

    return AppCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: const Icon(Icons.favorite_border, color: DesignTokens.rose),
        title: const Text('Cycle & Period Tracker'),
        subtitle: const Text('No period logged for this date.'),
        trailing: OutlinedButton(
          onPressed: () async {
            final dateObj = DateTime.parse(date);
            await ref.read(periodServiceProvider).logPeriodStartToday(dateObj);
            ref.invalidate(periodLogsStreamProvider);
            ref.invalidate(actualPeriodDatesProvider);
            ref.invalidate(predictedPeriodDatesProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Period start logged for this date!')),
              );
            }
          },
          child: const Text('Log Start'),
        ),
      ),
    );
  }
}
