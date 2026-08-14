import 'package:flutter/foundation.dart';

/// Data models for the rich Personal Projects management engine.

enum ProjectStatus {
  planning('Planning', '📝'),
  inProgress('In Progress', '⚡'),
  review('Review', '🔍'),
  completed('Completed', '✅'),
  onHold('On Hold', '⏸️');

  const ProjectStatus(this.label, this.emoji);
  final String label;
  final String emoji;

  static ProjectStatus fromString(String? val) {
    return ProjectStatus.values.firstWhere(
      (e) => e.name == val || e.label.toLowerCase() == val?.toLowerCase(),
      orElse: () => ProjectStatus.inProgress,
    );
  }
}

enum SubtaskStatus {
  todo('To Do', '📌'),
  inProgress('In Progress', '⚡'),
  review('Review', '🔍'),
  done('Done', '✅');

  const SubtaskStatus(this.label, this.emoji);
  final String label;
  final String emoji;

  static SubtaskStatus fromString(String? val) {
    return SubtaskStatus.values.firstWhere(
      (e) => e.name == val || e.label.toLowerCase() == val?.toLowerCase(),
      orElse: () => SubtaskStatus.todo,
    );
  }
}

@immutable
class ProjectUpdateEntry {
  final String id;
  final DateTime date;
  final String note;
  final double? hoursLogged;
  final String? statusChange;
  final List<String> images;

  const ProjectUpdateEntry({
    required this.id,
    required this.date,
    required this.note,
    this.hoursLogged,
    this.statusChange,
    this.images = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'note': note,
        if (hoursLogged != null) 'hoursLogged': hoursLogged,
        if (statusChange != null) 'statusChange': statusChange,
        if (images.isNotEmpty) 'images': images,
      };

  factory ProjectUpdateEntry.fromJson(Map<String, dynamic> json) {
    return ProjectUpdateEntry(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      note: json['note'] as String? ?? '',
      hoursLogged: (json['hoursLogged'] as num?)?.toDouble(),
      statusChange: json['statusChange'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

@immutable
class ProjectRichSubtask {
  final String id;
  final String title;
  final String description;
  final SubtaskStatus status;
  final double hours;
  final List<String> images;
  final List<ProjectUpdateEntry> updates;

  const ProjectRichSubtask({
    required this.id,
    required this.title,
    this.description = '',
    this.status = SubtaskStatus.todo,
    this.hours = 0.0,
    this.images = const [],
    this.updates = const [],
  });

  ProjectRichSubtask copyWith({
    String? title,
    String? description,
    SubtaskStatus? status,
    double? hours,
    List<String>? images,
    List<ProjectUpdateEntry>? updates,
  }) {
    return ProjectRichSubtask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      hours: hours ?? this.hours,
      images: images ?? this.images,
      updates: updates ?? this.updates,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.name,
        'hours': hours,
        'images': images,
        'updates': updates.map((u) => u.toJson()).toList(),
      };

  factory ProjectRichSubtask.fromJson(Map<String, dynamic> json) {
    return ProjectRichSubtask(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: SubtaskStatus.fromString(json['status'] as String?),
      hours: (json['hours'] as num?)?.toDouble() ?? 0.0,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      updates: (json['updates'] as List<dynamic>?)
              ?.map((e) => ProjectUpdateEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

@immutable
class ProjectMetaData {
  final ProjectStatus status;
  final String targetDate;
  final String category;
  final double totalHours;
  final List<ProjectRichSubtask> richSubtasks;
  final List<ProjectUpdateEntry> projectUpdates;

  const ProjectMetaData({
    this.status = ProjectStatus.inProgress,
    this.targetDate = '',
    this.category = 'General',
    this.totalHours = 0.0,
    this.richSubtasks = const [],
    this.projectUpdates = const [],
  });

  double get calculatedTotalHours {
    double subtaskHours = richSubtasks.fold(0.0, (sum, s) => sum + s.hours);
    double updateHours = projectUpdates.fold(0.0, (sum, u) => sum + (u.hoursLogged ?? 0.0));
    return subtaskHours + updateHours;
  }

  int get completedSubtasksCount =>
      richSubtasks.where((s) => s.status == SubtaskStatus.done).length;

  double get progressRatio {
    if (richSubtasks.isEmpty) return status == ProjectStatus.completed ? 1.0 : 0.0;
    return completedSubtasksCount / richSubtasks.length;
  }

  ProjectMetaData copyWith({
    ProjectStatus? status,
    String? targetDate,
    String? category,
    double? totalHours,
    List<ProjectRichSubtask>? richSubtasks,
    List<ProjectUpdateEntry>? projectUpdates,
  }) {
    return ProjectMetaData(
      status: status ?? this.status,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      totalHours: totalHours ?? this.totalHours,
      richSubtasks: richSubtasks ?? this.richSubtasks,
      projectUpdates: projectUpdates ?? this.projectUpdates,
    );
  }

  Map<String, dynamic> toJson() => {
        'project_status': status.name,
        'target_date': targetDate,
        'category': category,
        'total_hours': totalHours,
        'rich_subtasks': richSubtasks.map((s) => s.toJson()).toList(),
        'project_updates': projectUpdates.map((u) => u.toJson()).toList(),
      };

  factory ProjectMetaData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProjectMetaData();
    return ProjectMetaData(
      status: ProjectStatus.fromString(json['project_status'] as String?),
      targetDate: json['target_date'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0.0,
      richSubtasks: (json['rich_subtasks'] as List<dynamic>?)
              ?.map((e) => ProjectRichSubtask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      projectUpdates: (json['project_updates'] as List<dynamic>?)
              ?.map((e) => ProjectUpdateEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
