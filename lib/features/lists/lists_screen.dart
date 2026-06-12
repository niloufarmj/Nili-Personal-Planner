import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import 'repositories/collection_repository.dart';
import 'templates/template_registry.dart';
import 'widgets/collection_counts.dart';

/// Lists tab — grid of all list-engine collections.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(_allCollectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lists')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewListFlow(context, ref),
        tooltip: 'New list',
        child: const Icon(Icons.add),
      ),
      body: collectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (collections) {
          if (collections.isEmpty) {
            return EmptyState(
              icon: Icons.checklist,
              message: 'All your lists in one place',
              hint:
                  'Shopping, chores, uni tasks, job hunt and more — tap + to create a list.',
              action: () => _showNewListFlow(context, ref),
              actionLabel: 'Create first list',
            );
          }
          return _CollectionsGrid(collections: collections);
        },
      ),
    );
  }

  Future<void> _showNewListFlow(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_NewListResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewListSheet(),
    );
    if (result == null || !context.mounted) return;
    await ref
        .read(collectionRepositoryProvider)
        .create(
          name: result.name,
          template: result.template,
          icon: TemplateRegistry.get(result.template).icon.codePoint.toString(),
        );
  }
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final _allCollectionsProvider = StreamProvider<List<Collection>>(
  (ref) => ref.watch(collectionRepositoryProvider).watchAll(),
);

// ── Collections grid ──────────────────────────────────────────────────────────

class _CollectionsGrid extends StatelessWidget {
  const _CollectionsGrid({required this.collections});

  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    // Group by template kind
    final byTemplate = <String, List<Collection>>{};
    for (final c in collections) {
      (byTemplate[c.template] ??= []).add(c);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: byTemplate.length,
      itemBuilder: (context, i) {
        final templateId = byTemplate.keys.elementAt(i);
        final templateDef = TemplateRegistry.get(templateId);
        final cols = byTemplate[templateId]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: templateDef.label),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemCount: cols.length,
              itemBuilder: (context, j) => _CollectionCard(collection: cols[j]),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

// ── Single collection card ─────────────────────────────────────────────────────

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = TemplateRegistry.get(collection.template);

    return GestureDetector(
      onLongPress: () => _showContextMenu(context, ref),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push(Routes.collectionPath(collection.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(template.icon, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    collection.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            CollectionCounts(collectionId: collection.id, template: template),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_CardAction>(
      context: context,
      builder: (_) => _CollectionContextSheet(name: collection.name),
    );
    if (action == null || !context.mounted) return;

    final repo = ref.read(collectionRepositoryProvider);
    switch (action) {
      case _CardAction.rename:
        final newName = await _showRenameDialog(context, collection.name);
        if (newName != null && newName.trim().isNotEmpty) {
          await repo.rename(collection.id, newName.trim());
        }
      case _CardAction.archive:
        final confirmed = await ConfirmDialog.show(
          context,
          title: 'Archive "${collection.name}"?',
          message: 'Archived lists are hidden from this grid.',
          confirmLabel: 'Archive',
        );
        if (confirmed) await repo.archive(collection.id);
    }
  }

  Future<String?> _showRenameDialog(
    BuildContext context,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

enum _CardAction { rename, archive }

class _CollectionContextSheet extends StatelessWidget {
  const _CollectionContextSheet({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(name, style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () => Navigator.of(context).pop(_CardAction.rename),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archive'),
            onTap: () => Navigator.of(context).pop(_CardAction.archive),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── New list bottom sheet ──────────────────────────────────────────────────────

class _NewListResult {
  const _NewListResult({required this.name, required this.template});

  final String name;
  final String template;
}

class _NewListSheet extends StatefulWidget {
  const _NewListSheet();

  @override
  State<_NewListSheet> createState() => _NewListSheetState();
}

class _NewListSheetState extends State<_NewListSheet> {
  final _nameController = TextEditingController();
  String? _selectedTemplate;
  int? _step; // null=name, 0=template

  @override
  void initState() {
    super.initState();
    _step = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _goToTemplatePicker() {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _step = 0);
  }

  void _pickTemplate(String templateId) {
    setState(() => _selectedTemplate = templateId);
    Navigator.of(context).pop(
      _NewListResult(name: _nameController.text.trim(), template: templateId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _step == null ? _namePage() : _templatePage(),
      ),
    );
  }

  Widget _namePage() {
    return Column(
      key: const ValueKey('name'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('New list', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'List name',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _goToTemplatePicker(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _goToTemplatePicker,
          child: const Text('Next: pick template'),
        ),
      ],
    );
  }

  Widget _templatePage() {
    return Column(
      key: const ValueKey('template'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _step = null),
            ),
            Text(
              'Choose a template',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...TemplateRegistry.all.map(
          (t) => ListTile(
            leading: Icon(t.icon),
            title: Text(t.label),
            selected: _selectedTemplate == t.id,
            onTap: () => _pickTemplate(t.id),
          ),
        ),
      ],
    );
  }
}
