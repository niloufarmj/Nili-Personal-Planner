import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/item_repository.dart';

/// Inline expandable subtask list with checkboxes and add field.
class SubtaskList extends ConsumerStatefulWidget {
  const SubtaskList({required this.itemId, super.key});

  final int itemId;

  @override
  ConsumerState<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends ConsumerState<SubtaskList> {
  final _controller = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtasksAsync = ref.watch(_subtasksProvider(widget.itemId));
    final repo = ref.read(itemRepositoryProvider);

    return subtasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => Text('$e'),
      data: (subtasks) {
        final done = subtasks.where((s) => s.status == 'done').length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$done / ${subtasks.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ...subtasks.map(
              (s) => Row(
                children: [
                  Checkbox(
                    value: s.status == 'done',
                    onChanged: (_) => repo.toggleSubtask(s.id),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      s.title,
                      style: TextStyle(
                        decoration: s.status == 'done'
                            ? TextDecoration.lineThrough
                            : null,
                        color: s.status == 'done'
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => repo.deleteSubtask(s.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            if (_adding)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Subtask title',
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (v) => _save(repo, v),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _save(repo, _controller.text),
                    child: const Text('Add'),
                  ),
                ],
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add subtask'),
                onPressed: () => setState(() => _adding = true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _save(ItemRepository repo, String title) async {
    if (title.trim().isEmpty) {
      setState(() => _adding = false);
      return;
    }
    await repo.createSubtask(itemId: widget.itemId, title: title.trim());
    _controller.clear();
    setState(() => _adding = false);
  }
}

final _subtasksProvider = StreamProvider.family(
  (ref, int itemId) => ref.watch(itemRepositoryProvider).watchSubtasks(itemId),
);
