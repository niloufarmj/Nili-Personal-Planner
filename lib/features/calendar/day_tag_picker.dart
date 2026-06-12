import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/day_repository.dart';

final _allTagsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(dayRepositoryProvider).watchAllTags(),
);

final _activeTagsForDateProvider = FutureProvider.autoDispose
    .family<List<Tag>, String>(
      (ref, date) => ref.watch(dayRepositoryProvider).getTagsForDate(date),
    );

/// Inline tag picker shown on the day detail sheet.
/// Displays all available tags as chips; active ones are highlighted.
class DayTagPicker extends ConsumerWidget {
  const DayTagPicker({required this.date, super.key});

  final String date; // YYYY-MM-DD

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dayRepositoryProvider);

    final allTagsAsync = ref.watch(_allTagsProvider);
    final activeFuture = ref.watch(_activeTagsForDateProvider(date));

    return allTagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (allTags) => activeFuture.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (activeTags) {
          final activeIds = activeTags.map((t) => t.id).toSet();
          return Wrap(
            spacing: 8,
            runSpacing: 4,
            children: allTags.map((tag) {
              final isActive = activeIds.contains(tag.id);
              final color = _hexColor(tag.color);
              return FilterChip(
                label: Text(tag.name),
                selected: isActive,
                selectedColor: color.withAlpha(60),
                checkmarkColor: color,
                side: BorderSide(color: isActive ? color : Colors.transparent),
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                onSelected: (selected) async {
                  if (selected) {
                    await repo.setTag(date, tag.id);
                  } else {
                    await repo.removeTag(date, tag.id);
                  }
                  ref.invalidate(_activeTagsForDateProvider(date));
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

Color _hexColor(String hex) {
  final sanitized = hex.replaceAll('#', '');
  return Color(int.parse('FF$sanitized', radix: 16));
}
