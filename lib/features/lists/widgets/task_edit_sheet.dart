import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/design/design.dart';
import '../repositories/collection_repository.dart';
import '../repositories/item_repository.dart';

/// Bottom sheet for creating a new Task.
/// Allows picking due date, priority, and optional List (or "No List - Day Task").
class TaskEditSheet extends ConsumerStatefulWidget {
  const TaskEditSheet({
    super.key,
    this.initialDate,
    this.initialCollectionId,
  });

  final String? initialDate; // YYYY-MM-DD
  final int? initialCollectionId;

  static Future<void> show(
    BuildContext context, {
    String? initialDate,
    int? initialCollectionId,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => TaskEditSheet(
          initialDate: initialDate,
          initialCollectionId: initialCollectionId,
        ),
      );

  @override
  ConsumerState<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> {
  late final TextEditingController _titleCtrl;
  late DateTime _dueDate;
  String _priority = 'normal';
  int? _selectedCollectionId; // null = "No List (Day Task only)"

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _selectedCollectionId = widget.initialCollectionId;

    if (widget.initialDate != null) {
      final parts = widget.initialDate!.split('-');
      _dueDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } else {
      _dueDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final collectionsAsync = ref.watch(_allCollectionsStreamProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_box_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Due Date: ${DateFormat('EEE, MMM d, yyyy').format(_dueDate)}'),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),

              // Priority Selector
              const SectionHeader(
                title: 'Priority',
                padding: EdgeInsets.only(bottom: 8),
              ),
              Wrap(
                spacing: 8,
                children: ['low', 'normal', 'high'].map((p) {
                  return ChoiceChip(
                    label: Text(p.toUpperCase()),
                    selected: _priority == p,
                    onSelected: (_) => setState(() => _priority = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // List Selection
              const SectionHeader(
                title: 'Assign to List',
                padding: EdgeInsets.only(bottom: 8),
              ),
              collectionsAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (_, __) => const SizedBox.shrink(),
                data: (collections) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // No List option
                      ChoiceChip(
                        avatar: const Icon(Icons.today, size: 16),
                        label: const Text('No List (Day Task)'),
                        selected: _selectedCollectionId == null,
                        onSelected: (_) => setState(() => _selectedCollectionId = null),
                      ),
                      // Active collections
                      ...collections.map((c) {
                        return ChoiceChip(
                          label: Text(c.name),
                          selected: _selectedCollectionId == c.id,
                          onSelected: (_) => setState(() => _selectedCollectionId = c.id),
                        );
                      }),
                      // Create New List option
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('New List...'),
                        onPressed: _showCreateListDialog,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _save,
                child: const Text('Save Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _showCreateListDialog() async {
    final textCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New List'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'List Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(textCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final repo = ref.read(collectionRepositoryProvider);
      final newId = await repo.create(
        name: name,
        template: 'custom',
        icon: 'format_list_bulleted',
      );
      setState(() {
        _selectedCollectionId = newId;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final dateStr =
        '${_dueDate.year.toString().padLeft(4, '0')}-'
        '${_dueDate.month.toString().padLeft(2, '0')}-'
        '${_dueDate.day.toString().padLeft(2, '0')}';

    final collectionRepo = ref.read(collectionRepositoryProvider);
    final itemRepo = ref.read(itemRepositoryProvider);

    int targetCollectionId;
    if (_selectedCollectionId != null) {
      targetCollectionId = _selectedCollectionId!;
    } else {
      final defaultCol = await collectionRepo.getOrCreateGeneralTasksCollection();
      targetCollectionId = defaultCol.id;
    }

    int priorityInt = switch (_priority) {
      'high' => 1,
      'low' => 3,
      _ => 2,
    };

    final companion = ItemsCompanion(
      title: Value(title),
      collectionId: Value(targetCollectionId),
      dueDate: Value(dateStr),
      priority: Value(priorityInt),
      status: const Value('open'),
    );

    await itemRepo.createItem(companion);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "$title" added for ${DateFormat('MMM d').format(_dueDate)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

final _allCollectionsStreamProvider = StreamProvider.autoDispose<List<Collection>>((ref) {
  return ref.watch(collectionRepositoryProvider).watchAll();
});
