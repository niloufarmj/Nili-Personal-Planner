import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/design.dart';
import '../../../core/services/image_service.dart';
import '../models/project_models.dart';

class SubtaskDetailSheet extends ConsumerStatefulWidget {
  const SubtaskDetailSheet({
    required this.subtask,
    required this.onSave,
    required this.onDelete,
    super.key,
  });

  final ProjectRichSubtask subtask;
  final ValueChanged<ProjectRichSubtask> onSave;
  final VoidCallback onDelete;

  @override
  ConsumerState<SubtaskDetailSheet> createState() => _SubtaskDetailSheetState();
}

class _SubtaskDetailSheetState extends ConsumerState<SubtaskDetailSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _updateNoteCtrl;
  late SubtaskStatus _status;
  late double _hours;
  late List<String> _images;
  late List<ProjectUpdateEntry> _updates;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.subtask.title);
    _descCtrl = TextEditingController(text: widget.subtask.description);
    _updateNoteCtrl = TextEditingController();
    _status = widget.subtask.status;
    _hours = widget.subtask.hours;
    _images = List.from(widget.subtask.images);
    _updates = List.from(widget.subtask.updates);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _updateNoteCtrl.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final updated = widget.subtask.copyWith(
      title: _titleCtrl.text.trim().isEmpty ? 'Untitled Subtask' : _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      status: _status,
      hours: _hours,
      images: _images,
      updates: _updates,
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  Future<void> _pickImage() async {
    final path = await ref.read(imageServiceProvider).pick(source: ImageSource.gallery);
    if (path != null) {
      setState(() {
        _images.add(path);
      });
    }
  }

  void _addUpdateNote() {
    final text = _updateNoteCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _updates.insert(
        0,
        ProjectUpdateEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.now(),
          note: text,
        ),
      );
      _updateNoteCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final insets = MediaQuery.viewInsetsOf(context);

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + insets.bottom),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            children: [
              Text(
                'Subtask Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: inkColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: DesignTokens.danger),
                tooltip: 'Delete Subtask',
                onPressed: () {
                  widget.onDelete();
                  Navigator.of(context).pop();
                },
              ),
              IconButton(
                icon: const Icon(Icons.check_circle, color: DesignTokens.accentLight, size: 28),
                onPressed: _saveChanges,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              children: [
                // Title Field
                TextFormField(
                  controller: _titleCtrl,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: inkColor,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Subtask Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Status Selector Row
                Text(
                  'STATUS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: softInk,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SubtaskStatus.values.map((st) {
                    final isSelected = _status == st;
                    Color badgeColor;
                    switch (st) {
                      case SubtaskStatus.todo:
                        badgeColor = DesignTokens.rose;
                      case SubtaskStatus.inProgress:
                        badgeColor = DesignTokens.dustyBlue;
                      case SubtaskStatus.review:
                        badgeColor = DesignTokens.peach;
                      case SubtaskStatus.done:
                        badgeColor = DesignTokens.success;
                    }

                    return ChoiceChip(
                      avatar: Text(st.emoji),
                      label: Text(st.label),
                      selected: isSelected,
                      selectedColor: DesignTokens.resolvePastelFill(
                        color: badgeColor,
                        isDark: isDark,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? badgeColor : inkColor,
                      ),
                      side: BorderSide(
                        color: isSelected ? badgeColor : (isDark ? DesignTokens.lineDark : DesignTokens.lineLight),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() => _status = st);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Logged Hours Row
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: DesignTokens.accentLight),
                      const SizedBox(width: 10),
                      Text(
                        'Logged Hours:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: inkColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_hours.toStringAsFixed(1)} hrs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.accentLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          if (_hours >= 0.5) {
                            setState(() => _hours -= 0.5);
                          }
                        },
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() => _hours += 0.5);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Description Field
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: theme.textTheme.bodyMedium?.copyWith(color: inkColor),
                  decoration: InputDecoration(
                    labelText: 'Notes & Description',
                    hintText: 'Add implementation details, instructions, or scope notes...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Image Attachments Gallery
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ATTACHMENTS & IMAGES (${_images.length})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: softInk,
                        letterSpacing: 0.8,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text('Add Photo'),
                      onPressed: _pickImage,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_images.isEmpty)
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? DesignTokens.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No image attachments yet',
                        style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final imgPath = _images[idx];
                        final imgProvider = imageProviderFor(imgPath);
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 80,
                                height: 80,
                                color: isDark ? DesignTokens.surfaceDark : Colors.grey[200],
                                child: imgProvider != null
                                    ? Image(image: imgProvider, fit: BoxFit.cover)
                                    : Icon(Icons.image, color: softInk),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () => setState(() => _images.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 22),

                // Updates Log Stream
                Text(
                  'SUBTASK UPDATES & NOTES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: softInk,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _updateNoteCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add progress update...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: DesignTokens.accentLight,
                      ),
                      onPressed: _addUpdateNote,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_updates.isEmpty)
                  Text(
                    'No status updates recorded yet.',
                    style: theme.textTheme.bodySmall?.copyWith(color: softInk),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _updates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final u = _updates[idx];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? DesignTokens.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '📌 Progress Log',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: DesignTokens.accentLight,
                                  ),
                                ),
                                Text(
                                  '${u.date.day}/${u.date.month} ${u.date.hour.toString().padLeft(2, '0')}:${u.date.minute.toString().padLeft(2, '0')}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: softInk),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              u.note,
                              style: theme.textTheme.bodyMedium?.copyWith(color: inkColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
