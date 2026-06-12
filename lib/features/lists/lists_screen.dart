import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import 'repositories/collection_repository.dart';
import 'templates/template_registry.dart';
import 'widgets/collection_counts.dart';

// Helper to extract country flag emojis
String getCountryFlag(String name) {
  final cleanName = name.trim().toLowerCase();
  if (cleanName == 'germany') return '🇩🇪';
  if (cleanName == 'netherlands') return '🇳🇱';
  if (cleanName == 'spain') return '🇪🇸';
  if (cleanName == 'australia') return '🇦🇺';
  if (cleanName == 'austria') return '🇦🇹';
  if (cleanName == 'belgium') return '🇧🇪';
  if (cleanName == 'canada') return '🇨🇦';
  if (cleanName == 'france') return '🇫🇷';
  if (cleanName == 'italy') return '🇮🇹';
  return '';
}

String withCountryFlag(String name) {
  final flag = getCountryFlag(name);
  return flag.isNotEmpty ? '$flag $name' : name;
}

Color getTemplateSoftColor(String templateId, bool isDark) {
  if (isDark) {
    final baseColor = switch (templateId) {
      'simple' => DesignTokens.rose,
      'chore' => DesignTokens.sage,
      'shopping' => DesignTokens.peach,
      'upgrade' => DesignTokens.butter,
      'task' => DesignTokens.lavender,
      'job' => DesignTokens.dustyBlue,
      'growth' => DesignTokens.blush,
      'media' => DesignTokens.rose,
      'probable' => DesignTokens.lavender,
      _ => DesignTokens.rose,
    };
    return DesignTokens.resolvePastelFill(color: baseColor, isDark: true);
  } else {
    return switch (templateId) {
      'simple' => DesignTokens.roseSoft,
      'chore' => DesignTokens.sageSoft,
      'shopping' => DesignTokens.peachSoft,
      'upgrade' => DesignTokens.butterSoft,
      'task' => DesignTokens.lavenderSoft,
      'job' => DesignTokens.dustyBlueSoft,
      'growth' => DesignTokens.blushSoft,
      'media' => DesignTokens.roseSoft,
      'probable' => DesignTokens.lavenderSoft,
      _ => DesignTokens.roseSoft,
    };
  }
}

Color getTemplateMainColor(String templateId, bool isDark) {
  final color = switch (templateId) {
    'simple' => DesignTokens.rose,
    'chore' => DesignTokens.sage,
    'shopping' => DesignTokens.peach,
    'upgrade' => DesignTokens.butter,
    'task' => DesignTokens.lavender,
    'job' => DesignTokens.dustyBlue,
    'growth' => DesignTokens.blush,
    'media' => DesignTokens.rose,
    'probable' => DesignTokens.lavender,
    _ => DesignTokens.rose,
  };
  return isDark ? DesignTokens.adjustColorForDark(color) : color;
}

/// Lists tab — grid of all list-engine collections.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(_allCollectionsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lists',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewListFlow(context, ref),
        tooltip: 'New list',
        backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
        foregroundColor: Colors.white,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final result = await showModalBottomSheet<_NewListResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusSheet)),
      ),
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
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
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemCount: cols.length,
              itemBuilder: (context, j) => _CollectionCard(collection: cols[j]),
            ),
            const SizedBox(height: 16),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final softBg = getTemplateSoftColor(collection.template, isDark);
    final mainColor = getTemplateMainColor(collection.template, isDark);
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context, ref),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        color: softBg,
        onTap: () => context.push(Routes.collectionPath(collection.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? DesignTokens.surfaceDark : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(template.icon, size: 16, color: mainColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    withCountryFlag(collection.name),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: inkColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            CollectionProgressBar(
              collectionId: collection.id,
              template: template,
              mainColor: mainColor,
            ),
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
            title: Text(
              withCountryFlag(name),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
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
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + insets.bottom),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _step == null ? _namePage() : _templatePage(),
      ),
    );
  }

  Widget _namePage() {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('name'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'New list',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: GoogleFonts.fraunces().fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
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
          style: FilledButton.styleFrom(
            backgroundColor: theme.brightness == Brightness.dark
                ? DesignTokens.accentDark
                : DesignTokens.accentLight,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Next: pick template'),
        ),
      ],
    );
  }

  Widget _templatePage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: GoogleFonts.fraunces().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: TemplateRegistry.all.map(
            (t) {
              final isSelected = _selectedTemplate == t.id;
              final mainColor = getTemplateMainColor(t.id, isDark);
              final softColor = getTemplateSoftColor(t.id, isDark);
              final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

              return GestureDetector(
                onTap: () => _pickTemplate(t.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: softColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? mainColor : (isDark ? DesignTokens.lineDark : DesignTokens.lineLight),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 16, color: mainColor),
                      const SizedBox(width: 8),
                      Text(
                        t.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle, size: 16, color: DesignTokens.success),
                      ],
                    ],
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ],
    );
  }
}


