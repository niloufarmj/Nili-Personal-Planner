import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/services/image_service.dart';
import '../lists/repositories/item_repository.dart';
import 'models/project_models.dart';
import 'widgets/subtask_detail_sheet.dart';

class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const ProjectWorkspaceScreen({
    required this.item,
    super.key,
  });

  final Item item;

  @override
  ConsumerState<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends ConsumerState<ProjectWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late ProjectMetaData _meta;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleCtrl = TextEditingController(text: widget.item.title);
    _descCtrl = TextEditingController(text: widget.item.description ?? '');
    _meta = ProjectMetaData.fromJson(widget.item.meta);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveMeta(ProjectMetaData newMeta, {String? newTitle, String? newDesc}) async {
    final repo = ref.read(itemRepositoryProvider);
    final updatedTitle = newTitle ?? _titleCtrl.text.trim();
    final updatedDesc = newDesc ?? _descCtrl.text.trim();

    await repo.updateItem(
      widget.item.copyWith(
        title: updatedTitle.isEmpty ? 'Untitled Project' : updatedTitle,
        description: Value(updatedDesc),
        meta: Value(newMeta.toJson()),
      ),
    );
    setState(() {
      _meta = newMeta;
    });
  }

  void _addSubtask() {
    final newSubtask = ProjectRichSubtask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Subtask',
      status: SubtaskStatus.todo,
    );
    final updatedSubtasks = [..._meta.richSubtasks, newSubtask];
    _saveMeta(_meta.copyWith(richSubtasks: updatedSubtasks));
    _openSubtaskSheet(newSubtask);
  }

  void _openSubtaskSheet(ProjectRichSubtask subtask) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubtaskDetailSheet(
        subtask: subtask,
        onSave: (saved) {
          final list = _meta.richSubtasks.map((s) => s.id == saved.id ? saved : s).toList();
          _saveMeta(_meta.copyWith(richSubtasks: list));
        },
        onDelete: () {
          final list = _meta.richSubtasks.where((s) => s.id != subtask.id).toList();
          _saveMeta(_meta.copyWith(richSubtasks: list));
        },
      ),
    );
  }

  Future<void> _postProjectUpdate() async {
    final noteCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    String? pickedImagePath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.rate_review, color: DesignTokens.accentLight),
              SizedBox(width: 8),
              Text('Post Project Update'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Update Note / Milestone',
                    hintText: 'Describe progress, changes, or roadmap update...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Log Hours (optional)',
                    hintText: 'e.g. 2.5',
                    prefixIcon: Icon(Icons.timer_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: Text(pickedImagePath == null ? 'Attach Photo' : 'Photo Attached!'),
                      onPressed: () async {
                        final path = await ref.read(imageServiceProvider).pick(source: ImageSource.gallery);
                        if (path != null) {
                          setDialogState(() => pickedImagePath = path);
                        }
                      },
                    ),
                  ],
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
                final text = noteCtrl.text.trim();
                if (text.isNotEmpty) {
                  final hrs = double.tryParse(hoursCtrl.text.trim());
                  final newEntry = ProjectUpdateEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    date: DateTime.now(),
                    note: text,
                    hoursLogged: hrs,
                    images: pickedImagePath != null ? [pickedImagePath!] : const [],
                  );
                  final updatedList = [newEntry, ..._meta.projectUpdates];
                  _saveMeta(_meta.copyWith(projectUpdates: updatedList));
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    final totalHrs = _meta.calculatedTotalHours;
    final progressRatio = _meta.progressRatio;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleCtrl.text),
        actions: [
          PopupMenuButton<ProjectStatus>(
            initialValue: _meta.status,
            icon: Chip(
              avatar: Text(_meta.status.emoji),
              label: Text(_meta.status.label),
              backgroundColor: DesignTokens.resolvePastelFill(
                color: DesignTokens.rose,
                isDark: isDark,
              ),
              side: BorderSide.none,
            ),
            onSelected: (newStatus) {
              HapticFeedback.selectionClick();
              _saveMeta(_meta.copyWith(status: newStatus));
            },
            itemBuilder: (_) => ProjectStatus.values
                .map(
                  (st) => PopupMenuItem(
                    value: st,
                    child: Row(
                      children: [
                        Text(st.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(st.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: DesignTokens.accentLight,
          labelColor: DesignTokens.accentLight,
          unselectedLabelColor: softInk,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Subtasks'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Updates'),
            Tab(icon: Icon(Icons.photo_library_outlined), text: 'Gallery'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Project Summary Header Box ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? DesignTokens.surfaceDark : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description Box
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(color: inkColor),
                  decoration: const InputDecoration(
                    hintText: 'Project description or objective...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) => _saveMeta(_meta, newDesc: val),
                ),
                const SizedBox(height: 10),

                // Stats & Progress Bar Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_meta.completedSubtasksCount} of ${_meta.richSubtasks.length} subtasks done',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: softInk,
                                ),
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
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: DesignTokens.resolvePastelFill(
                          color: DesignTokens.dustyBlue,
                          isDark: isDark,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: DesignTokens.dustyBlue),
                          const SizedBox(width: 4),
                          Text(
                            '${totalHrs.toStringAsFixed(1)} h',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Tab Views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Subtasks List
                _buildSubtasksTab(theme, isDark, inkColor, softInk),

                // Tab 2: Updates Log Stream
                _buildUpdatesTab(theme, isDark, inkColor, softInk),

                // Tab 3: Image Gallery Grid
                _buildGalleryTab(theme, isDark, softInk),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Subtask'),
        backgroundColor: DesignTokens.accentLight,
        foregroundColor: Colors.white,
        onPressed: _addSubtask,
      ),
    );
  }

  // ── Tab 1: Subtasks ────────────────────────────────────────────────────────
  Widget _buildSubtasksTab(ThemeData theme, bool isDark, Color inkColor, Color softInk) {
    final subtasks = _meta.richSubtasks;
    if (subtasks.isEmpty) {
      return EmptyState(
        icon: Icons.account_tree_outlined,
        message: 'No subtasks created yet',
        hint: 'Tap "Add Subtask" below to break down your project!',
        actionLabel: 'Add Subtask',
        action: _addSubtask,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: subtasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final st = subtasks[idx];
        final isDone = st.status == SubtaskStatus.done;

        Color badgeColor;
        switch (st.status) {
          case SubtaskStatus.todo:
            badgeColor = DesignTokens.rose;
          case SubtaskStatus.inProgress:
            badgeColor = DesignTokens.dustyBlue;
          case SubtaskStatus.review:
            badgeColor = DesignTokens.peach;
          case SubtaskStatus.done:
            badgeColor = DesignTokens.success;
        }

        return AppCard(
          padding: const EdgeInsets.all(14),
          child: InkWell(
            onTap: () => _openSubtaskSheet(st),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Checkbox
                    IconButton(
                      icon: Icon(
                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isDone ? DesignTokens.success : softInk,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final newStatus = isDone ? SubtaskStatus.todo : SubtaskStatus.done;
                        final updated = st.copyWith(status: newStatus);
                        final list = subtasks.map((s) => s.id == st.id ? updated : s).toList();
                        _saveMeta(_meta.copyWith(richSubtasks: list));
                      },
                    ),
                    const SizedBox(width: 4),

                    // Title
                    Expanded(
                      child: Text(
                        st.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDone ? softInk : inkColor,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: DesignTokens.resolvePastelFill(
                          color: badgeColor,
                          isDark: isDark,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(st.status.emoji, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            st.status.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? DesignTokens.inkDark : badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (st.description.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 48, top: 4),
                    child: Text(
                      st.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    children: [
                      if (st.hours > 0) ...[
                        const Icon(Icons.timer_outlined, size: 13, color: DesignTokens.dustyBlue),
                        const SizedBox(width: 4),
                        Text(
                          '${st.hours.toStringAsFixed(1)} hrs',
                          style: theme.textTheme.labelSmall?.copyWith(color: softInk),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (st.images.isNotEmpty) ...[
                        const Icon(Icons.image_outlined, size: 13, color: DesignTokens.rose),
                        const SizedBox(width: 4),
                        Text(
                          '${st.images.length} photos',
                          style: theme.textTheme.labelSmall?.copyWith(color: softInk),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (st.updates.isNotEmpty) ...[
                        const Icon(Icons.chat_bubble_outline, size: 13, color: DesignTokens.accentLight),
                        const SizedBox(width: 4),
                        Text(
                          '${st.updates.length} notes',
                          style: theme.textTheme.labelSmall?.copyWith(color: softInk),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 2: Updates ─────────────────────────────────────────────────────────
  Widget _buildUpdatesTab(ThemeData theme, bool isDark, Color inkColor, Color softInk) {
    final updates = _meta.projectUpdates;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROJECT TIMELINE & LOGS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: softInk,
                  letterSpacing: 0.8,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Post Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.accentLight,
                  foregroundColor: Colors.white,
                ),
                onPressed: _postProjectUpdate,
              ),
            ],
          ),
        ),
        Expanded(
          child: updates.isEmpty
              ? EmptyState(
                  icon: Icons.chat_bubble_outline,
                  message: 'No project updates recorded yet',
                  hint: 'Post notes, progress updates, or log work hours!',
                  actionLabel: 'Post Update',
                  action: _postProjectUpdate,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: updates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final u = updates[idx];
                    final dateStr = '${u.date.day}/${u.date.month}/${u.date.year} ${u.date.hour.toString().padLeft(2, '0')}:${u.date.minute.toString().padLeft(2, '0')}';

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: DesignTokens.roseSoft,
                                child: Icon(Icons.rocket_launch, size: 14, color: DesignTokens.rose),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Project Log Entry',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: inkColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateStr,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: softInk),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            u.note,
                            style: theme.textTheme.bodyMedium?.copyWith(color: inkColor),
                          ),
                          if (u.hoursLogged != null) ...[
                            const SizedBox(height: 6),
                            Chip(
                              avatar: const Icon(Icons.timer, size: 14, color: DesignTokens.accentLight),
                              label: Text('+${u.hoursLogged!.toStringAsFixed(1)} hrs logged'),
                              side: BorderSide.none,
                            ),
                          ],
                          if (u.images.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: u.images.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, imgIdx) {
                                  final provider = imageProviderFor(u.images[imgIdx]);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      color: isDark ? DesignTokens.surfaceDark : Colors.grey[200],
                                      child: provider != null
                                          ? Image(image: provider, fit: BoxFit.cover)
                                          : const Icon(Icons.image),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Tab 3: Gallery ─────────────────────────────────────────────────────────
  Widget _buildGalleryTab(ThemeData theme, bool isDark, Color softInk) {
    final List<String> allImages = [];
    for (final st in _meta.richSubtasks) {
      allImages.addAll(st.images);
    }
    for (final u in _meta.projectUpdates) {
      allImages.addAll(u.images);
    }

    if (allImages.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        message: 'No project photos attached',
        hint: 'Attach screenshots, diagrams, or progress photos inside subtasks!',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: allImages.length,
      itemBuilder: (context, idx) {
        final imgPath = allImages[idx];
        final provider = imageProviderFor(imgPath);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: isDark ? DesignTokens.surfaceDark : Colors.grey[200],
            child: provider != null
                ? Image(image: provider, fit: BoxFit.cover)
                : Icon(Icons.image, color: softInk),
          ),
        );
      },
    );
  }
}
