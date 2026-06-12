import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/social_repository.dart';

final _socialAccountsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(socialRepositoryProvider).watchAccounts(),
);

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(_socialAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Social')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'social_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showAddAccountSheet(context, ref),
      ),
      body: accountsAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const EmptyState(
              icon: Icons.share,
              message: 'No accounts yet',
              hint: 'Add your social media accounts to start tracking.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: accounts.length,
            itemBuilder: (_, i) => _AccountCard(account: accounts[i]),
          );
        },
      ),
    );
  }

  Future<void> _showAddAccountSheet(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _AccountAddSheet(),
      );
}

// ── Account card ──────────────────────────────────────────────────────────────

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});

  final SocialAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(socialRepositoryProvider);

    return FutureBuilder<List<SocialLog>>(
      future: repo.getLogsForAccount(account.id),
      builder: (context, snap) {
        final logs = snap.data ?? [];
        final today = DateTime.now();
        final streak = SocialRepository.computeStreak(logs, today);
        final daysAgo = SocialRepository.daysAgoLastPost(logs, today);

        return AppCard(
          child: ExpansionTile(
            title: Text(account.platform),
            subtitle: Text(
              daysAgo == null
                  ? 'Never posted'
                  : daysAgo == 0
                  ? 'Posted today · Streak: $streak 🔥'
                  : 'Last posted ${daysAgo}d ago · Streak: $streak',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _showLogSheet(context, account.id),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
            children: [
              if (account.goal != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(account.goal!)),
                    ],
                  ),
                ),
              _WeeklyBarChart(accountId: account.id, logs: logs),
              const Divider(height: 1),
              _LogHistory(accountId: account.id),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete account'),
                onTap: () async {
                  final confirmed = await ConfirmDialog.show(
                    context,
                    title: 'Delete account?',
                    message: 'Delete "${account.platform}" and all its logs?',
                  );
                  if (confirmed == true) {
                    await ref
                        .read(socialRepositoryProvider)
                        .deleteAccount(account.id);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLogSheet(BuildContext context, int accountId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _LogAddSheet(accountId: accountId),
      );
}

// ── Weekly bar chart ──────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.accountId, required this.logs});

  final int accountId;
  final List<SocialLog> logs;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekly = SocialRepository.weeklyMinutes(logs, weekStart, 6);

    if (weekly.values.every((v) => v == 0)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No usage data', style: TextStyle(color: Colors.grey)),
      );
    }

    final entries = weekly.entries.toList();
    final barGroups = entries.indexed.map(((int, MapEntry<String, int>) e) {
      final (i, entry) = e;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    final date = entries[i].key;
                    return Text(
                      date.substring(5, 10),
                      style: const TextStyle(fontSize: 9),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
          ),
        ),
      ),
    );
  }
}

final _socialLogsForAccountProvider = StreamProvider.autoDispose.family<List<SocialLog>, int>(
  (ref, id) => ref.watch(socialRepositoryProvider).watchLogsForAccount(id),
);

// ── Log history ───────────────────────────────────────────────────────────────

class _LogHistory extends ConsumerWidget {
  const _LogHistory({required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_socialLogsForAccountProvider(accountId));

    return logsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('$e'),
      data: (logs) {
        if (logs.isEmpty) return const SizedBox.shrink();
        final recent = logs.take(5).toList();
        return Column(
          children: recent
              .map(
                (l) => ListTile(
                  dense: true,
                  title: Text(l.date),
                  subtitle: Text(
                    [
                      if (l.activity != null) l.activity!,
                      if (l.minutesSpent != null) '${l.minutesSpent}min',
                      if (l.note != null) l.note!,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () =>
                        ref.read(socialRepositoryProvider).deleteLog(l.id),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ── Account add sheet ─────────────────────────────────────────────────────────

class _AccountAddSheet extends ConsumerStatefulWidget {
  const _AccountAddSheet();

  @override
  ConsumerState<_AccountAddSheet> createState() => _AccountAddSheetState();
}

class _AccountAddSheetState extends ConsumerState<_AccountAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _platformCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  @override
  void dispose() {
    _platformCtrl.dispose();
    _goalCtrl.dispose();
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
            Text('Add Account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _platformCtrl,
              decoration: const InputDecoration(
                labelText: 'Platform (e.g. Instagram)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _goalCtrl,
              decoration: const InputDecoration(
                labelText: 'Goal (optional)',
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
        .read(socialRepositoryProvider)
        .createAccount(
          platform: _platformCtrl.text.trim(),
          goal: _goalCtrl.text.trim().isEmpty ? null : _goalCtrl.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }
}

// ── Log add sheet ─────────────────────────────────────────────────────────────

class _LogAddSheet extends ConsumerStatefulWidget {
  const _LogAddSheet({required this.accountId});

  final int accountId;

  @override
  ConsumerState<_LogAddSheet> createState() => _LogAddSheetState();
}

class _LogAddSheetState extends ConsumerState<_LogAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _minutesCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _activity;

  @override
  void dispose() {
    _minutesCtrl.dispose();
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
              'Log Activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['post', 'story', 'comment', 'browse']
                  .map(
                    (a) => ChoiceChip(
                      label: Text(a),
                      selected: _activity == a,
                      onSelected: (_) => setState(() => _activity = a),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes (optional)',
                border: OutlineInputBorder(),
              ),
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
            FilledButton(onPressed: _submit, child: const Text('Log')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final minutes = int.tryParse(_minutesCtrl.text.trim());
    await ref
        .read(socialRepositoryProvider)
        .createLog(
          SocialLogsCompanion.insert(
            accountId: widget.accountId,
            date: dateStr,
            minutesSpent: Value(minutes),
            activity: Value(_activity),
            note: Value(
              _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}
