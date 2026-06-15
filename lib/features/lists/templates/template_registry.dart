import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';

// ── Field types ───────────────────────────────────────────────────────────────

enum MetaFieldType { text, url, number, select }

class MetaFieldDef {
  const MetaFieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.options,
    this.required = false,
  });

  final String key;
  final String label;
  final MetaFieldType type;
  final List<String>? options; // for select
  final bool required;
}

// ── Status definition ─────────────────────────────────────────────────────────

class StatusDef {
  const StatusDef({
    required this.value,
    required this.label,
    required this.color,
    this.isDone = false,
  });

  final String value;
  final String label;
  final Color color;

  /// Whether reaching this status should set done_date.
  final bool isDone;
}

// ── Visible fields bitmask ────────────────────────────────────────────────────

class VisibleFields {
  const VisibleFields({
    this.priority = false,
    this.dueDate = false,
    this.plannedCost = false,
    this.recurrence = false,
    this.imageBefore = false,
    this.imageAfter = false,
    this.subtasks = false,
    this.description = false,
  });

  final bool priority;
  final bool dueDate;
  final bool plannedCost;
  final bool recurrence;
  final bool imageBefore;
  final bool imageAfter;
  final bool subtasks;
  final bool description;
}

// ── Template definition ───────────────────────────────────────────────────────

class TemplateDef {
  const TemplateDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.statuses,
    required this.fields,
    this.metaFields = const [],
    required this.defaultSort,
    required this.openStatus,
    required this.doneStatus,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<StatusDef> statuses;
  final VisibleFields fields;
  final List<MetaFieldDef> metaFields;

  /// Column name used for default ascending sort ('priority', 'dueDate', 'title').
  final String defaultSort;

  /// Status value that represents "open/not started".
  final String openStatus;

  /// Status value that represents "done/complete" (sets done_date).
  final String doneStatus;

  StatusDef statusDef(String value) => statuses.firstWhere(
    (s) => s.value == value,
    orElse: () => statuses.first,
  );
}

// ── Registry ──────────────────────────────────────────────────────────────────

abstract final class TemplateRegistry {
  static final Map<String, TemplateDef> _all = {
    for (final t in _templates) t.id: t,
  };

  static TemplateDef get(String id) => _all[id] ?? _all['simple']!;

  static List<TemplateDef> get all => List.unmodifiable(_templates);
}

// ── The 9 templates ───────────────────────────────────────────────────────────

const _templates = [
  // 1. simple
  TemplateDef(
    id: 'simple',
    label: 'Simple list',
    icon: Icons.checklist,
    openStatus: 'open',
    doneStatus: 'done',
    defaultSort: 'priority',
    statuses: [
      StatusDef(value: 'open', label: 'Open', color: AppColors.statusOpen),
      StatusDef(
        value: 'done',
        label: 'Done',
        color: AppColors.statusDone,
        isDone: true,
      ),
    ],
    fields: VisibleFields(priority: true, dueDate: true, description: true),
  ),

  // 2. chore
  TemplateDef(
    id: 'chore',
    label: 'Chores',
    icon: Icons.home_outlined,
    openStatus: 'open',
    doneStatus: 'done',
    defaultSort: 'dueDate',
    statuses: [
      StatusDef(value: 'open', label: 'Open', color: AppColors.statusOpen),
      StatusDef(
        value: 'done',
        label: 'Done',
        color: AppColors.statusDone,
        isDone: true,
      ),
    ],
    fields: VisibleFields(dueDate: true, recurrence: true, description: true),
    metaFields: [
      MetaFieldDef(key: 'room', label: 'Room', type: MetaFieldType.text),
    ],
  ),

  // 3. shopping
  TemplateDef(
    id: 'shopping',
    label: 'Shopping',
    icon: Icons.shopping_cart_outlined,
    openStatus: 'wanted',
    doneStatus: 'bought',
    defaultSort: 'priority',
    statuses: [
      StatusDef(value: 'wanted', label: 'Wanted', color: AppColors.statusOpen),
      StatusDef(
        value: 'bought',
        label: 'Bought',
        color: AppColors.statusDone,
        isDone: true,
      ),
    ],
    fields: VisibleFields(priority: true, plannedCost: true, description: true),
    metaFields: [
      MetaFieldDef(key: 'shop_url', label: 'Shop URL', type: MetaFieldType.url),
    ],
  ),

  // 4. upgrade
  TemplateDef(
    id: 'upgrade',
    label: 'Life Upgrades',
    icon: Icons.upgrade_outlined,
    openStatus: 'planned',
    doneStatus: 'done',
    defaultSort: 'priority',
    statuses: [
      StatusDef(
        value: 'planned',
        label: 'Planned',
        color: AppColors.statusPlanned,
      ),
      StatusDef(
        value: 'done',
        label: 'Done',
        color: AppColors.statusDone,
        isDone: true,
      ),
    ],
    fields: VisibleFields(
      priority: true,
      plannedCost: true,
      imageBefore: true,
      imageAfter: true,
      description: true,
    ),
  ),

  // 5. task
  TemplateDef(
    id: 'task',
    label: 'Tasks',
    icon: Icons.task_alt_outlined,
    openStatus: 'todo',
    doneStatus: 'done',
    defaultSort: 'priority',
    statuses: [
      StatusDef(value: 'todo', label: 'To Do', color: AppColors.statusOpen),
      StatusDef(
        value: 'in_progress',
        label: 'In Progress',
        color: Color(0xFFFFF9C4),
      ),
      StatusDef(
        value: 'done',
        label: 'Done',
        color: AppColors.statusDone,
        isDone: true,
      ),
      StatusDef(
        value: 'blocked',
        label: 'Blocked',
        color: AppColors.statusBlocked,
      ),
    ],
    fields: VisibleFields(
      priority: true,
      dueDate: true,
      subtasks: true,
      description: true,
    ),
    metaFields: [
      MetaFieldDef(
        key: 'course',
        label: 'Course / Context',
        type: MetaFieldType.text,
      ),
    ],
  ),

  // 6. job
  TemplateDef(
    id: 'job',
    label: 'Job Hunt',
    icon: Icons.work_outline,
    openStatus: 'researching',
    doneStatus: 'offer',
    defaultSort: 'priority',
    statuses: [
      StatusDef(
        value: 'researching',
        label: 'Researching',
        color: AppColors.statusOpen,
      ),
      StatusDef(
        value: 'applied',
        label: 'Applied',
        color: AppColors.statusPlanned,
      ),
      StatusDef(
        value: 'interview',
        label: 'Interview',
        color: Color(0xFFFFF9C4),
      ),
      StatusDef(
        value: 'rejected',
        label: 'Rejected',
        color: AppColors.statusBlocked,
      ),
      StatusDef(
        value: 'offer',
        label: 'Offer',
        color: AppColors.statusDone,
        isDone: true,
      ),
    ],
    fields: VisibleFields(priority: true, dueDate: true, description: true),
    metaFields: [
      MetaFieldDef(key: 'company', label: 'Company', type: MetaFieldType.text),
      MetaFieldDef(key: 'role', label: 'Role', type: MetaFieldType.text),
      MetaFieldDef(key: 'link', label: 'Job Link', type: MetaFieldType.url),
      MetaFieldDef(
        key: 'email',
        label: 'Contact Email',
        type: MetaFieldType.text,
      ),
      MetaFieldDef(
        key: 'contact',
        label: 'Contact Name',
        type: MetaFieldType.text,
      ),
    ],
  ),

  // 7. growth
  TemplateDef(
    id: 'growth',
    label: 'Personal Growth',
    icon: Icons.trending_up,
    openStatus: 'planned',
    doneStatus: 'done',
    defaultSort: 'priority',
    statuses: [
      StatusDef(
        value: 'planned',
        label: 'Planned',
        color: AppColors.statusPlanned,
      ),
      StatusDef(value: 'active', label: 'Active', color: Color(0xFFFFF9C4)),
      StatusDef(
        value: 'done',
        label: 'Done',
        color: AppColors.statusDone,
        isDone: true,
      ),
    ],
    fields: VisibleFields(priority: true, dueDate: true, description: true),
    metaFields: [
      MetaFieldDef(
        key: 'resource_link',
        label: 'Resource Link',
        type: MetaFieldType.url,
      ),
      MetaFieldDef(
        key: 'target_hours',
        label: 'Target Hours',
        type: MetaFieldType.number,
      ),
      MetaFieldDef(
        key: 'result',
        label: 'Result / Notes',
        type: MetaFieldType.text,
      ),
    ],
  ),

  // 8. media
  TemplateDef(
    id: 'media',
    label: 'Hobbies & Media',
    icon: Icons.movie_outlined,
    openStatus: 'backlog',
    doneStatus: 'done',
    defaultSort: 'title',
    statuses: [
      StatusDef(
        value: 'backlog',
        label: 'Backlog',
        color: AppColors.statusOpen,
      ),
      StatusDef(value: 'active', label: 'Active', color: Color(0xFFFFF9C4)),
      StatusDef(
        value: 'done',
        label: 'Done',
        color: AppColors.statusDone,
        isDone: true,
      ),
    ],
    fields: VisibleFields(description: true),
    metaFields: [
      MetaFieldDef(
        key: 'kind',
        label: 'Kind',
        type: MetaFieldType.select,
        options: ['book', 'movie', 'series', 'game', 'other'],
      ),
      MetaFieldDef(
        key: 'total_time_spent',
        label: 'Time Spent (h)',
        type: MetaFieldType.number,
      ),
    ],
  ),

  // 9. probable
  TemplateDef(
    id: 'probable',
    label: 'Probable Plans',
    icon: Icons.lightbulb_outline,
    openStatus: 'undecided',
    doneStatus: 'promoted',
    defaultSort: 'priority',
    statuses: [
      StatusDef(
        value: 'undecided',
        label: 'Undecided',
        color: AppColors.statusOpen,
      ),
      StatusDef(
        value: 'promoted',
        label: 'Promoted',
        color: AppColors.statusDone,
        isDone: true,
      ),
      StatusDef(
        value: 'dropped',
        label: 'Dropped',
        color: AppColors.statusBlocked,
      ),
    ],
    fields: VisibleFields(priority: true, dueDate: true, description: true),
    metaFields: [
      MetaFieldDef(
        key: 'promote_target',
        label: 'Promote To',
        type: MetaFieldType.text,
      ),
    ],
  ),
];
