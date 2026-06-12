class SeedTag {
  final String name;
  final String color;
  final String kind;
  final String owner;

  SeedTag({
    required this.name,
    required this.color,
    required this.kind,
    required this.owner,
  });

  factory SeedTag.fromJson(Map<String, dynamic> json) {
    return SeedTag(
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      owner: json['owner'] as String? ?? 'me',
    );
  }
}

class SeedItemMedia {
  final String title;
  final String kind;
  final String status;

  SeedItemMedia({
    required this.title,
    required this.kind,
    required this.status,
  });

  factory SeedItemMedia.fromJson(Map<String, dynamic> json) {
    return SeedItemMedia(
      title: json['title'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class SeedItemShopping {
  final String title;
  final int? priority;
  final String status;
  final String? stage;
  final int? costCents;
  final String? costNote;

  SeedItemShopping({
    required this.title,
    this.priority,
    required this.status,
    this.stage,
    this.costCents,
    this.costNote,
  });

  factory SeedItemShopping.fromJson(Map<String, dynamic> json) {
    return SeedItemShopping(
      title: json['title'] as String? ?? '',
      priority: json['priority'] as int?,
      status: json['status'] as String? ?? '',
      stage: json['stage'] as String?,
      costCents: json['cost_cents'] as int?,
      costNote: json['cost_note'] as String?,
    );
  }
}

class SeedItemJob {
  final String title;
  final String status;
  final int? priority;
  final String? dueDate;
  final String? note;

  SeedItemJob({
    required this.title,
    required this.status,
    this.priority,
    this.dueDate,
    this.note,
  });

  factory SeedItemJob.fromJson(Map<String, dynamic> json) {
    return SeedItemJob(
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      priority: json['priority'] as int?,
      dueDate: json['due_date'] as String?,
      note: json['note'] as String?,
    );
  }
}

class SeedCollection {
  final String name;
  final String template;
  final String? icon;
  final String? parent;
  final List<SeedItemMedia> itemsMedia;
  final List<SeedItemShopping> itemsShopping;
  final List<SeedItemJob> itemsJob;

  SeedCollection({
    required this.name,
    required this.template,
    this.icon,
    this.parent,
    required this.itemsMedia,
    required this.itemsShopping,
    required this.itemsJob,
  });

  factory SeedCollection.fromJson(Map<String, dynamic> json) {
    return SeedCollection(
      name: json['name'] as String? ?? '',
      template: json['template'] as String? ?? '',
      icon: json['icon'] as String?,
      parent: json['parent'] as String?,
      itemsMedia:
          (json['items_media'] as List?)
              ?.map((e) => SeedItemMedia.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      itemsShopping:
          (json['items_shopping'] as List?)
              ?.map((e) => SeedItemShopping.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      itemsJob:
          (json['items_job'] as List?)
              ?.map((e) => SeedItemJob.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SeedIngredient {
  final String name;
  final String category;

  SeedIngredient({required this.name, required this.category});

  factory SeedIngredient.fromJson(Map<String, dynamic> json) {
    return SeedIngredient(
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
    );
  }
}

class SeedWorkoutPlan {
  final String name;
  final String content;

  SeedWorkoutPlan({required this.name, required this.content});

  factory SeedWorkoutPlan.fromJson(Map<String, dynamic> json) {
    return SeedWorkoutPlan(
      name: json['name'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class SeedInitialMeasurement {
  final String date;
  final double weightKg;
  final String? note;

  SeedInitialMeasurement({
    required this.date,
    required this.weightKg,
    this.note,
  });

  factory SeedInitialMeasurement.fromJson(Map<String, dynamic> json) {
    return SeedInitialMeasurement(
      date: json['date'] as String? ?? '',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
    );
  }
}

class SeedGoal {
  final String metric;
  final double target;
  final String? deadline;
  final String? note;

  SeedGoal({
    required this.metric,
    required this.target,
    this.deadline,
    this.note,
  });

  factory SeedGoal.fromJson(Map<String, dynamic> json) {
    return SeedGoal(
      metric: json['metric'] as String? ?? '',
      target: (json['target'] as num?)?.toDouble() ?? 0.0,
      deadline: json['deadline'] as String?,
      note: json['note'] as String?,
    );
  }
}

class SeedFitness {
  final SeedInitialMeasurement? initialMeasurement;
  final List<SeedGoal> goals;

  SeedFitness({this.initialMeasurement, required this.goals});

  factory SeedFitness.fromJson(Map<String, dynamic> json) {
    final initJson = json['initial_measurement'] as Map<String, dynamic>?;
    return SeedFitness(
      initialMeasurement: initJson != null
          ? SeedInitialMeasurement.fromJson(initJson)
          : null,
      goals:
          (json['goals'] as List?)
              ?.map((e) => SeedGoal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SeedHabit {
  final String name;
  final int targetPerDay;
  final List<String> reminderTimes;

  SeedHabit({
    required this.name,
    required this.targetPerDay,
    required this.reminderTimes,
  });

  factory SeedHabit.fromJson(Map<String, dynamic> json) {
    return SeedHabit(
      name: json['name'] as String? ?? '',
      targetPerDay: json['target_per_day'] as int? ?? 1,
      reminderTimes:
          (json['reminder_times'] as List?)?.map((e) => e as String).toList() ??
          [],
    );
  }
}

class SeedDebt {
  final String person;
  final int amountCents;
  final String direction;
  final String? note;

  SeedDebt({
    required this.person,
    required this.amountCents,
    required this.direction,
    this.note,
  });

  factory SeedDebt.fromJson(Map<String, dynamic> json) {
    return SeedDebt(
      person: json['person'] as String? ?? '',
      amountCents: json['amount_cents'] as int? ?? 0,
      direction: json['direction'] as String? ?? '',
      note: json['note'] as String?,
    );
  }
}

class SeedData {
  final int version;
  final String generated;
  final List<SeedTag> tags;
  final List<SeedCollection> collections;
  final List<SeedIngredient> ingredientsMaster;
  final List<SeedWorkoutPlan> workoutPlans;
  final SeedFitness fitness;
  final List<SeedHabit> habits;
  final List<SeedDebt> debts;

  SeedData({
    required this.version,
    required this.generated,
    required this.tags,
    required this.collections,
    required this.ingredientsMaster,
    required this.workoutPlans,
    required this.fitness,
    required this.habits,
    required this.debts,
  });

  factory SeedData.fromJson(Map<String, dynamic> json) {
    final fitnessJson = json['fitness'] as Map<String, dynamic>? ?? {};
    return SeedData(
      version: json['version'] as int? ?? 1,
      generated: json['generated'] as String? ?? '',
      tags:
          (json['tags'] as List?)
              ?.map((e) => SeedTag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      collections:
          (json['collections'] as List?)
              ?.map((e) => SeedCollection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ingredientsMaster:
          (json['ingredients_master'] as List?)
              ?.map((e) => SeedIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      workoutPlans:
          (json['workout_plans'] as List?)
              ?.map((e) => SeedWorkoutPlan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      fitness: SeedFitness.fromJson(fitnessJson),
      habits:
          (json['habits'] as List?)
              ?.map((e) => SeedHabit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      debts:
          (json['debts'] as List?)
              ?.map((e) => SeedDebt.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
