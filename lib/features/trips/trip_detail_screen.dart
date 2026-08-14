import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import 'models/trip_models.dart';
import 'trip_edit_sheet.dart';
import 'trip_repository.dart';
import 'widgets/ticket_edit_sheet.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(_tripProvider(tripId));
    return tripAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: ShimmerSkeleton(width: double.infinity, height: 200),
        ),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (trip) {
        if (trip == null) {
          return const Scaffold(body: Center(child: Text('Trip not found')));
        }
        return _TripDetailView(trip: trip);
      },
    );
  }
}

final _tripProvider = StreamProvider.autoDispose.family<Trip?, int>(
  (ref, id) => ref.watch(tripRepositoryProvider).watchById(id),
);

class _TripDetailView extends ConsumerStatefulWidget {
  const _TripDetailView({required this.trip});
  final Trip trip;

  @override
  ConsumerState<_TripDetailView> createState() => _TripDetailViewState();
}

class _TripDetailViewState extends ConsumerState<_TripDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TripMetaData _meta;
  final _newTaskCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _meta = TripMetaData.fromJson(widget.trip.meta);
  }

  @override
  void didUpdateWidget(covariant _TripDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip.meta != oldWidget.trip.meta) {
      _meta = TripMetaData.fromJson(widget.trip.meta);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newTaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveMeta(TripMetaData newMeta) async {
    final repo = ref.read(tripRepositoryProvider);
    await repo.updateTrip(
      widget.trip.copyWith(
        meta: Value(newMeta.toJson()),
      ),
    );
    setState(() {
      _meta = newMeta;
    });
  }

  void _editTicket(bool isOutbound) {
    final initialTicket = isOutbound ? _meta.outboundTicket : _meta.returnTicket;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TicketEditSheet(
        title: isOutbound ? 'Outbound Ticket Details' : 'Return Ticket Details',
        initialData: initialTicket,
        onSave: (savedTicket) {
          final updated = isOutbound
              ? _meta.copyWith(outboundTicket: savedTicket)
              : _meta.copyWith(returnTicket: savedTicket);
          _saveMeta(updated);
        },
      ),
    );
  }

  void _addTask() {
    final title = _newTaskCtrl.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.lightImpact();
    final newTask = TripTaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    );
    final updatedTasks = [..._meta.tasks, newTask];
    _saveMeta(_meta.copyWith(tasks: updatedTasks));
    _newTaskCtrl.clear();
  }

  void _toggleTask(TripTaskItem task) {
    HapticFeedback.selectionClick();
    final updatedTasks = _meta.tasks
        .map((t) => t.id == task.id ? TripTaskItem(id: t.id, title: t.title, isDone: !t.isDone) : t)
        .toList();
    _saveMeta(_meta.copyWith(tasks: updatedTasks));
  }

  void _deleteTask(String id) {
    final updatedTasks = _meta.tasks.where((t) => t.id != id).toList();
    _saveMeta(_meta.copyWith(tasks: updatedTasks));
  }

  Future<void> _addLocationDialog() async {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Attraction';
    String status = 'Must Visit';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.place, color: DesignTokens.accentLight),
              SizedBox(width: 8),
              Text('Add Place to Visit'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Place Name',
                    hintText: 'e.g. Naqsh-e Jahan Square',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Attraction', child: Text('🏛️ Attraction')),
                    DropdownMenuItem(value: 'Food', child: Text('🍽️ Food & Dining')),
                    DropdownMenuItem(value: 'Hotel', child: Text('🏨 Hotel / Stay')),
                    DropdownMenuItem(value: 'Activity', child: Text('🎟️ Activity')),
                    DropdownMenuItem(value: 'Shopping', child: Text('🛍️ Shopping')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Priority / Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Must Visit', child: Text('⭐ Must Visit')),
                    DropdownMenuItem(value: 'Planned', child: Text('📌 Planned')),
                    DropdownMenuItem(value: 'Visited', child: Text('✅ Visited')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address / Notes',
                    hintText: 'e.g. Open 9am-6pm, buy tickets in advance',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final newPlace = TripLocationItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    category: category,
                    status: status,
                    notes: notesCtrl.text.trim(),
                  );
                  final updatedList = [..._meta.placesToVisit, newPlace];
                  _saveMeta(_meta.copyWith(placesToVisit: updatedList));
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Add Place'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteLocation(String id) {
    final updatedList = _meta.placesToVisit.where((p) => p.id != id).toList();
    _saveMeta(_meta.copyWith(placesToVisit: updatedList));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = DateFormat('d MMM yyyy');

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    final trip = widget.trip;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          trip.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: inkColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => TripEditSheet.show(context, existing: trip),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(context, ref, v),
            itemBuilder: (_) => [
              if (trip.status == 'probable')
                const PopupMenuItem(
                  value: 'finalize',
                  child: Text('Mark as Final'),
                ),
              if (trip.status == 'final')
                const PopupMenuItem(value: 'done', child: Text('Mark Done')),
              if (trip.status != 'cancelled')
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel trip'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: DesignTokens.accentLight,
          labelColor: DesignTokens.accentLight,
          unselectedLabelColor: softInk,
          tabs: const [
            Tab(icon: Icon(Icons.flight), text: 'Tickets'),
            Tab(icon: Icon(Icons.checklist), text: 'Tasks & Packing'),
            Tab(icon: Icon(Icons.place), text: 'Places to Visit'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Trip Header Summary ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: isDark ? DesignTokens.surfaceDark : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusChip(status: trip.status),
                          const SizedBox(width: 8),
                          if (trip.location != null) ...[
                            Icon(Icons.place, size: 14, color: softInk),
                            const SizedBox(width: 2),
                            Text(
                              trip.location!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: softInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (trip.startDate != null && trip.endDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📅 ${fmt.format(_parseDate(trip.startDate!))} – ${fmt.format(_parseDate(trip.endDate!))}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trip.budgetCents != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: DesignTokens.resolvePastelFill(
                        color: DesignTokens.sage,
                        isDark: isDark,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      CurrencyFormatter.format(trip.budgetCents!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.sage,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Workspace Tabs ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Flights & Tickets
                _buildTicketsTab(theme, isDark, inkColor, softInk),

                // Tab 2: Tasks & Packing List
                _buildTasksTab(theme, isDark, inkColor, softInk),

                // Tab 3: Places to Visit List
                _buildPlacesTab(theme, isDark, inkColor, softInk),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Flight & Ticket Data ───────────────────────────────────────────
  Widget _buildTicketsTab(ThemeData theme, bool isDark, Color inkColor, Color softInk) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Outbound Ticket Card
        _buildTicketCard(
          theme: theme,
          isDark: isDark,
          title: '🛫 Outbound Ticket',
          ticket: _meta.outboundTicket,
          onEdit: () => _editTicket(true),
        ),
        const SizedBox(height: 16),

        // Return Ticket Card
        _buildTicketCard(
          theme: theme,
          isDark: isDark,
          title: '🛬 Return Ticket',
          ticket: _meta.returnTicket,
          onEdit: () => _editTicket(false),
        ),
      ],
    );
  }

  Widget _buildTicketCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required TicketData ticket,
    required VoidCallback onEdit,
  }) {
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: inkColor,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 14),
                label: Text(ticket.isEmpty ? 'Add Ticket' : 'Edit'),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (ticket.isEmpty)
            Text(
              'No ticket info added yet. Tap "Add Ticket" to record flight/train details.',
              style: theme.textTheme.bodySmall?.copyWith(color: softInk),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.resolvePastelFill(
                  color: DesignTokens.dustyBlue,
                  isDark: isDark,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ticket.carrier.isEmpty ? 'Carrier / Airline' : ticket.carrier,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                      ),
                      Text(
                        ticket.flightNumber,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.accentLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.departureAirport.isEmpty ? 'ORIGIN' : ticket.departureAirport,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                          Text(
                            '${ticket.departureDate} ${ticket.departureTime}',
                            style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward, color: DesignTokens.accentLight),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            ticket.arrivalAirport.isEmpty ? 'DESTINATION' : ticket.arrivalAirport,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                          const Text('Arrival'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                if (ticket.terminalGate.isNotEmpty) ...[
                  Icon(Icons.door_sliding_outlined, size: 14, color: softInk),
                  const SizedBox(width: 4),
                  Text('Gate: ${ticket.terminalGate}', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 16),
                ],
                if (ticket.seat.isNotEmpty) ...[
                  Icon(Icons.airline_seat_recline_normal, size: 14, color: softInk),
                  const SizedBox(width: 4),
                  Text('Seat: ${ticket.seat}', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 16),
                ],
                if (ticket.pnrCode.isNotEmpty) ...[
                  Icon(Icons.qr_code, size: 14, color: softInk),
                  const SizedBox(width: 4),
                  Text('PNR: ${ticket.pnrCode}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Tasks & Packing List ───────────────────────────────────────────
  Widget _buildTasksTab(ThemeData theme, bool isDark, Color inkColor, Color softInk) {
    final tasks = _meta.tasks;
    final doneCount = tasks.where((t) => t.isDone).length;
    final totalCount = tasks.length;
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add Task Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newTaskCtrl,
                decoration: InputDecoration(
                  hintText: 'Add task or packing item (e.g. Passport, Charger)...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _addTask(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: DesignTokens.accentLight,
              ),
              onPressed: _addTask,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Progress Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PACKING & TRIP CHECKLIST',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: softInk,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '$doneCount of $totalCount packed',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: doneCount == totalCount && totalCount > 0
                    ? DesignTokens.success
                    : DesignTokens.accentLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? DesignTokens.success : DesignTokens.accentLight,
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (tasks.isEmpty)
          EmptyState(
            icon: Icons.checklist,
            message: 'No packing items yet',
            hint: 'Add items above to make sure you never forget your passport or chargers!',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final task = tasks[idx];
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: task.isDone,
                    onChanged: (_) => _toggleTask(task),
                  ),
                  title: Text(
                    task.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: task.isDone ? softInk : inkColor,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deleteTask(task.id),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ── Tab 3: Places & Locations to Visit ────────────────────────────────────
  Widget _buildPlacesTab(ThemeData theme, bool isDark, Color inkColor, Color softInk) {
    final places = _meta.placesToVisit;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PLACES TO VISIT (${places.length})',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: softInk,
                letterSpacing: 0.8,
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_location_alt, size: 16),
              label: const Text('Add Place'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.accentLight,
                foregroundColor: Colors.white,
              ),
              onPressed: _addLocationDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (places.isEmpty)
          EmptyState(
            icon: Icons.place_outlined,
            message: 'No places saved yet',
            hint: 'Tap "Add Place" to bookmark attractions, restaurants, and hotels!',
            actionLabel: 'Add Place',
            action: _addLocationDialog,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final place = places[idx];

              String categoryEmoji;
              switch (place.category) {
                case 'Food':
                  categoryEmoji = '🍽️';
                case 'Hotel':
                  categoryEmoji = '🏨';
                case 'Activity':
                  categoryEmoji = '🎟️';
                case 'Shopping':
                  categoryEmoji = '🛍️';
                default:
                  categoryEmoji = '🏛️';
              }

              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: DesignTokens.resolvePastelFill(
                          color: DesignTokens.rose,
                          isDark: isDark,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(categoryEmoji, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  place.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: inkColor,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(place.status),
                                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                padding: EdgeInsets.zero,
                                side: BorderSide.none,
                              ),
                            ],
                          ),
                          if (place.notes.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              place.notes,
                              style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _deleteLocation(place.id),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repo = ref.read(tripRepositoryProvider);
    switch (action) {
      case 'finalize':
        await repo.finalizeTrip(widget.trip.id);
      case 'done':
        await repo.markDone(widget.trip.id);
      case 'cancel':
        final ok = await ConfirmDialog.show(
          context,
          title: 'Cancel trip?',
          message: 'Travel tags for this trip will be removed.',
        );
        if (ok == true) await repo.cancelTrip(widget.trip.id);
      case 'delete':
        final ok = await ConfirmDialog.show(
          context,
          title: 'Delete trip?',
          message: 'This cannot be undone.',
        );
        if (ok == true) {
          await repo.deleteTrip(widget.trip.id);
          if (context.mounted) context.pop();
        }
    }
  }

  static DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}
