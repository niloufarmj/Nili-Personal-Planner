import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'partner_repository.dart';

class PartnerScreen extends ConsumerWidget {
  const PartnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Partner Schedule'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Events'),
              Tab(text: 'Tags'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PartnerEventsTab(), _PartnerTagsTab()],
        ),
      ),
    );
  }
}

// ── Events tab ────────────────────────────────────────────────────────────────

class _PartnerEventsTab extends ConsumerWidget {
  const _PartnerEventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_partnerEventsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'partner_event_fab',
        onPressed: () => _showEventSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: eventsAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_outline,
              message: 'No partner events',
              hint: 'Tap + to add exams, deadlines or repeating events',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (_, i) => _PartnerEventCard(events[i]),
          );
        },
      ),
    );
  }

  void _showEventSheet(BuildContext context, WidgetRef ref) =>
      _PartnerEventSheet.show(context);
}

final _partnerEventsProvider = StreamProvider.autoDispose<List<Event>>(
  (ref) => ref.watch(partnerRepositoryProvider).watchPartnerEvents(),
);

class _PartnerEventCard extends ConsumerWidget {
  const _PartnerEventCard(this.event);
  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM yyyy');
    final parts = event.date.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    return AppCard(
      child: ListTile(
        leading: const Icon(Icons.favorite_outline, color: Color(0xFFAB47BC)),
        title: Text(event.title),
        subtitle: Text(fmt.format(date)),
        trailing: event.rrule != null
            ? const Icon(Icons.repeat, size: 16)
            : null,
        onTap: () => _PartnerEventSheet.show(context, existing: event),
        onLongPress: () async {
          final ok = await ConfirmDialog.show(
            context,
            title: 'Delete event?',
            message: 'This cannot be undone.',
          );
          if (ok == true) {
            await ref
                .read(partnerRepositoryProvider)
                .deletePartnerEvent(event.id);
          }
        },
      ),
    );
  }
}

// ── Tags tab ──────────────────────────────────────────────────────────────────

class _PartnerTagsTab extends ConsumerWidget {
  const _PartnerTagsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(_partnerTagsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'partner_tag_fab',
        onPressed: () => _showTagSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tagsAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tags) {
          if (tags.isEmpty) {
            return const EmptyState(
              icon: Icons.label_outline,
              message: 'No partner tags',
              hint: 'Tap + to create a partner availability tag',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            itemBuilder: (_, i) {
              final t = tags[i];
              return AppCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _parseHex(t.color),
                    radius: 12,
                  ),
                  title: Text(t.name),
                  subtitle: Text(t.kind),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: 'Delete tag?',
                        message: 'All day assignments will also be removed.',
                      );
                      if (ok == true) {
                        await ref
                            .read(partnerRepositoryProvider)
                            .deletePartnerTag(t.id);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showTagSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PartnerTagSheet(ref: ref),
    );
  }

  static Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

final _partnerTagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(partnerRepositoryProvider).watchPartnerTags(),
);

// ── Partner tag creation sheet ────────────────────────────────────────────────

class _PartnerTagSheet extends StatefulWidget {
  const _PartnerTagSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_PartnerTagSheet> createState() => _PartnerTagSheetState();
}

class _PartnerTagSheetState extends State<_PartnerTagSheet> {
  final _name = TextEditingController();
  final String _color = '#AB47BC';
  String _kind = 'partner';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New partner tag',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tag name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Kind'),
            items: const [
              DropdownMenuItem(value: 'partner', child: Text('Partner')),
              DropdownMenuItem(value: 'activity', child: Text('Activity')),
              DropdownMenuItem(value: 'location', child: Text('Location')),
            ],
            onChanged: (v) => setState(() => _kind = v!),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              final navigator = Navigator.of(context);
              await widget.ref
                  .read(partnerRepositoryProvider)
                  .createPartnerTag(
                    name: _name.text.trim(),
                    color: _color,
                    kind: _kind,
                  );
              navigator.pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ── Partner event creation sheet ──────────────────────────────────────────────

class _PartnerEventSheet extends ConsumerStatefulWidget {
  const _PartnerEventSheet({this.existing});
  final Event? existing;

  static Future<void> show(BuildContext context, {Event? existing}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _PartnerEventSheet(existing: existing),
      );

  @override
  ConsumerState<_PartnerEventSheet> createState() => _PartnerEventSheetState();
}

class _PartnerEventSheetState extends ConsumerState<_PartnerEventSheet> {
  final _title = TextEditingController();
  DateTime? _date;
  String _category = 'partner';
  String? _rrule;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title.text = e?.title ?? '';
    if (e?.date != null) {
      final p = e!.date.split('-');
      _date = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    _category = e?.category ?? 'partner';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Partner Event' : 'Edit Event',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title *'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date *'),
              child: Text(_date != null ? fmt.format(_date!) : 'Pick date'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'partner', child: Text('Partner')),
              DropdownMenuItem(
                value: 'appointment',
                child: Text('Appointment'),
              ),
              DropdownMenuItem(value: 'uni', child: Text('Uni/Work')),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(widget.existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _date == null) return;
    final repo = ref.read(partnerRepositoryProvider);
    final dateStr =
        '${_date!.year.toString().padLeft(4, '0')}-'
        '${_date!.month.toString().padLeft(2, '0')}-'
        '${_date!.day.toString().padLeft(2, '0')}';

    if (widget.existing == null) {
      await repo.createPartnerEvent(
        title: _title.text.trim(),
        date: dateStr,
        category: _category,
        rrule: _rrule,
      );
    } else {
      await repo.updatePartnerEvent(
        widget.existing!.copyWith(
          title: _title.text.trim(),
          date: dateStr,
          category: _category,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
