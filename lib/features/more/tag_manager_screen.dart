import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';

/// Tag manager accessible from the More tab.
/// Create, edit color/kind, archive tags.
class TagManagerScreen extends ConsumerWidget {
  const TagManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(
      StreamProvider((ref) => ref.watch(dayRepositoryProvider).watchAllTags()),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tags')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Error loading tags',
          hint: e.toString(),
        ),
        data: (tags) {
          if (tags.isEmpty) {
            return const EmptyState(
              icon: Icons.label_outline,
              message: 'No tags yet',
              hint: 'Tap + to create your first tag. Sample: "linz", "gym".',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _TagTile(
              tag: tags[i],
              onEdit: () => _showTagSheet(context, ref, existing: tags[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTagSheet(
    BuildContext context,
    WidgetRef ref, {
    Tag? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TagEditSheet(existing: existing, ref: ref),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({required this.tag, required this.onEdit});

  final Tag tag;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(tag.color);
    return AppCard(
      onTap: onEdit,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tag.name, style: Theme.of(context).textTheme.titleSmall),
                Text(tag.kind, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 18),
        ],
      ),
    );
  }
}

class _TagEditSheet extends StatefulWidget {
  const _TagEditSheet({required this.existing, required this.ref});

  final Tag? existing;
  final WidgetRef ref;

  @override
  State<_TagEditSheet> createState() => _TagEditSheetState();
}

class _TagEditSheetState extends State<_TagEditSheet> {
  late final TextEditingController _nameCtrl;
  late String _color;
  late String _kind;

  static const _kinds = ['location', 'activity', 'special', 'partner'];
  static const _presetColors = [
    '#F5C518',
    '#7C5CBF',
    '#3EBF6F',
    '#EF6C00',
    '#1565C0',
    '#AB47BC',
    '#E53935',
    '#00ACC1',
    '#43A047',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color ?? _presetColors.first;
    _kind = widget.existing?.kind ?? 'activity';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
                isEdit ? 'Edit Tag' : 'New Tag',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tag name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Color',
                padding: EdgeInsets.only(bottom: 8),
              ),
              Wrap(
                spacing: 8,
                children: _presetColors.map((hex) {
                  final selected = _color == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _hexColor(hex),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Kind',
                padding: EdgeInsets.only(bottom: 8),
              ),
              Wrap(
                spacing: 8,
                children: _kinds.map((k) {
                  return ChoiceChip(
                    label: Text(k),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: Text(isEdit ? 'Save' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final repo = widget.ref.read(dayRepositoryProvider);
    if (widget.existing != null) {
      await repo.updateTag(
        widget.existing!.copyWith(name: name, color: _color, kind: _kind),
      );
    } else {
      await repo.createTag(name: name, color: _color, kind: _kind);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

Color _hexColor(String hex) {
  final sanitized = hex.replaceAll('#', '');
  return Color(int.parse('FF$sanitized', radix: 16));
}
