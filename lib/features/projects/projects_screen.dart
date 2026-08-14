import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/services/image_service.dart';
import '../lists/repositories/collection_repository.dart';
import '../lists/repositories/item_repository.dart';
import 'models/project_models.dart';
import 'project_workspace_screen.dart';

final _projectItemsProvider = StreamProvider.autoDispose.family<List<Item>, int>((ref, collectionId) {
  return ref.watch(itemRepositoryProvider).watchItems(collectionId);
});

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({
    required this.collection,
    super.key,
  });

  final Collection collection;

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final itemsAsync = ref.watch(_projectItemsProvider(widget.collection.id));

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header Banner ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.collection.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/headers/header_projects.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: DesignTokens.resolvePastelFill(
                        color: DesignTokens.dustyBlue,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark ? DesignTokens.paperDark : DesignTokens.paperLight).withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Dashboard Overview Content ────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: itemsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error loading projects: $e')),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.account_tree_outlined,
                      message: 'No projects created yet',
                      hint: 'Tap + to launch your first personal project!',
                      actionLabel: 'New Project',
                      action: () => _showNewProjectDialog(context),
                    ),
                  );
                }

                int totalProjects = items.length;
                int inProgressCount = 0;
                int completedCount = 0;
                double grandTotalHours = 0.0;

                for (final item in items) {
                  final meta = ProjectMetaData.fromJson(item.meta);
                  if (meta.status == ProjectStatus.inProgress) inProgressCount++;
                  if (meta.status == ProjectStatus.completed) completedCount++;
                  grandTotalHours += meta.calculatedTotalHours;
                }

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Summary Stats Cards Row ──────────────────────────────
                    Row(
                      children: [
                        _buildStatBox(
                          theme,
                          isDark,
                          'Projects',
                          '$totalProjects',
                          Icons.folder_outlined,
                          DesignTokens.dustyBlue,
                        ),
                        const SizedBox(width: 8),
                        _buildStatBox(
                          theme,
                          isDark,
                          'Active',
                          '$inProgressCount',
                          Icons.bolt,
                          DesignTokens.rose,
                        ),
                        const SizedBox(width: 8),
                        _buildStatBox(
                          theme,
                          isDark,
                          'Logged',
                          '${grandTotalHours.toStringAsFixed(1)}h',
                          Icons.timer_outlined,
                          DesignTokens.sage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Section Title ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'YOUR PROJECTS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: softInk,
                          ),
                        ),
                        Text(
                          '$totalProjects items',
                          style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── List of Project Cards ────────────────────────────────
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        final meta = ProjectMetaData.fromJson(item.meta);
                        final progressRatio = meta.progressRatio;
                        final totalHours = meta.calculatedTotalHours;

                        Color badgeColor;
                        switch (meta.status) {
                          case ProjectStatus.planning:
                            badgeColor = DesignTokens.lavender;
                          case ProjectStatus.inProgress:
                            badgeColor = DesignTokens.dustyBlue;
                          case ProjectStatus.review:
                            badgeColor = DesignTokens.peach;
                          case ProjectStatus.completed:
                            badgeColor = DesignTokens.success;
                          case ProjectStatus.onHold:
                            badgeColor = Colors.grey;
                        }

                        return AppCard(
                          padding: const EdgeInsets.all(16),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ProjectWorkspaceScreen(item: item),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title & Status Pill Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: inkColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: DesignTokens.resolvePastelFill(
                                          color: badgeColor,
                                          isDark: isDark,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(meta.status.emoji, style: const TextStyle(fontSize: 12)),
                                          const SizedBox(width: 4),
                                          Text(
                                            meta.status.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? DesignTokens.inkDark : badgeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onPressed: () => _showProjectContextMenu(item),
                                    ),
                                  ],
                                ),

                                if (item.description != null && item.description!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.description!,
                                    style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],

                                const SizedBox(height: 14),

                                // Progress Bar
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${meta.completedSubtasksCount}/${meta.richSubtasks.length} subtasks completed',
                                          style: theme.textTheme.labelSmall?.copyWith(color: softInk),
                                        ),
                                        Text(
                                          '${(progressRatio * 100).toInt()}%',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: DesignTokens.accentLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progressRatio,
                                        minHeight: 6,
                                        backgroundColor: isDark
                                            ? DesignTokens.lineDark
                                            : DesignTokens.lineLight,
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          DesignTokens.accentLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Bottom Quick Stats Row
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined, size: 14, color: softInk),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${totalHours.toStringAsFixed(1)} hrs',
                                      style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.account_tree_outlined, size: 14, color: softInk),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${meta.richSubtasks.length} subtasks',
                                      style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'Workspace →',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: DesignTokens.accentLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
        backgroundColor: DesignTokens.accentLight,
        foregroundColor: Colors.white,
        onPressed: () => _showNewProjectDialog(context),
      ),
    );
  }

  Widget _buildStatBox(
    ThemeData theme,
    bool isDark,
    String label,
    String val,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignTokens.resolvePastelFill(color: color, isDark: isDark),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              val,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewProjectDialog(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    ProjectStatus selectedStatus = ProjectStatus.inProgress;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: DesignTokens.accentLight),
            SizedBox(width: 8),
            Text('Create New Project'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'e.g. Personal Portfolio Website, Fitness Plan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description / Goal',
                hintText: 'Brief objective or scope notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                final repo = ref.read(itemRepositoryProvider);
                final initialMeta = ProjectMetaData(status: selectedStatus);

                await repo.createItem(
                  ItemsCompanion(
                    collectionId: Value(widget.collection.id),
                    title: Value(title),
                    description: Value(
                      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    ),
                    meta: Value(initialMeta.toJson()),
                  ),
                );
              }
              if (context.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProjectContextMenu(Item item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: DesignTokens.danger),
              title: const Text('Delete Project', style: TextStyle(color: DesignTokens.danger)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'delete' && mounted) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Delete Project?',
        message: 'Remove "${item.title}" and all its subtasks & updates?',
      );
      if (confirmed == true) {
        await ref.read(itemRepositoryProvider).deleteItem(item.id);
      }
    }
  }
}
