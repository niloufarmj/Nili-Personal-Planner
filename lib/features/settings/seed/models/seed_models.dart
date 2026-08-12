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
  final String? company;
  final String? category;
  final String? city;
  final String? website;
  final String? linkedin;

  SeedItemJob({
    required this.title,
    required this.status,
    this.priority,
    this.dueDate,
    this.note,
    this.company,
    this.category,
    this.city,
    this.website,
    this.linkedin,
  });

  factory SeedItemJob.fromJson(Map<String, dynamic> json) {
    return SeedItemJob(
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      priority: json['priority'] as int?,
      dueDate: json['due_date'] as String?,
      note: json['note'] as String?,
      company: json['company'] as String?,
      category: json['category'] as String?,
      city: json['city'] as String?,
      website: json['website'] as String?,
      linkedin: json['linkedin'] as String?,
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

class SeedPeriodLog {
  final String startDate;
  final int durationDays;

  SeedPeriodLog({
    required this.startDate,
    required this.durationDays,
  });

  factory SeedPeriodLog.fromJson(Map<String, dynamic> json) {
    return SeedPeriodLog(
      startDate: json['start_date'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 5,
    );
  }
}

class SeedRecipeIngredient {
  final String name;
  final double amount;
  final String unit;

  SeedRecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory SeedRecipeIngredient.fromJson(Map<String, dynamic> json) {
    return SeedRecipeIngredient(
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'g',
    );
  }
}

class SeedRecipe {
  final String name;
  final String mealSlot;
  final int? prepMinutes;
  final int? proteinGrams;
  final int? calories;
  final List<String> tags;
  final String? instructions;
  final List<SeedRecipeIngredient> ingredients;

  SeedRecipe({
    required this.name,
    required this.mealSlot,
    this.prepMinutes,
    this.proteinGrams,
    this.calories,
    required this.tags,
    this.instructions,
    required this.ingredients,
  });

  factory SeedRecipe.fromJson(Map<String, dynamic> json) {
    return SeedRecipe(
      name: json['name'] as String? ?? '',
      mealSlot: json['meal_slot'] as String? ?? 'any',
      prepMinutes: json['prep_minutes'] as int?,
      proteinGrams: json['protein_grams'] as int?,
      calories: json['calories'] as int?,
      tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      instructions: json['instructions'] as String?,
      ingredients:
          (json['ingredients'] as List?)
              ?.map(
                (e) => SeedRecipeIngredient.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class SeedSportActivity {
  final String date;
  final String activityType;
  final int durationMin;
  final int? calories;
  final String? notes;

  SeedSportActivity({
    required this.date,
    required this.activityType,
    required this.durationMin,
    this.calories,
    this.notes,
  });

  factory SeedSportActivity.fromJson(Map<String, dynamic> json) {
    return SeedSportActivity(
      date: json['date'] as String? ?? '',
      activityType: json['activity_type'] as String? ?? 'Other',
      durationMin: json['duration_min'] as int? ?? 0,
      calories: json['calories'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

class SeedData {
  final int version;
  final String generated;
  final List<SeedTag> tags;
  final List<SeedCollection> collections;
  final List<SeedIngredient> ingredientsMaster;
  final List<SeedRecipe> recipesMaster;
  final List<SeedWorkoutPlan> workoutPlans;
  final SeedFitness fitness;
  final List<SeedHabit> habits;
  final List<SeedDebt> debts;
  final List<SeedPeriodLog> periodLogs;
  final List<SeedSportActivity> sportActivities;

  SeedData({
    required this.version,
    required this.generated,
    required this.tags,
    required this.collections,
    required this.ingredientsMaster,
    required this.recipesMaster,
    required this.workoutPlans,
    required this.fitness,
    required this.habits,
    required this.debts,
    required this.periodLogs,
    required this.sportActivities,
    required this.recurringTransactions,
    required this.initialTransactions,
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
      recipesMaster:
          (json['recipes_master'] as List?)
              ?.map((e) => SeedRecipe.fromJson(e as Map<String, dynamic>))
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
      periodLogs:
          (json['period_logs'] as List?)
              ?.map((e) => SeedPeriodLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sportActivities:
          (json['sport_activities'] as List?)
              ?.map((e) => SeedSportActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recurringTransactions:
          (json['recurring_transactions'] as List?)
              ?.map((e) => SeedRecurringTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      initialTransactions:
          (json['initial_transactions'] as List?)
              ?.map((e) => SeedInitialTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  final List<SeedRecurringTransaction> recurringTransactions;
  final List<SeedInitialTransaction> initialTransactions;
}

class SeedRecurringTransaction {
  final String name;
  final int amountCents;
  final String direction;
  final int dayOfMonth;
  final String startMonth;
  final String category;

  SeedRecurringTransaction({
    required this.name,
    required this.amountCents,
    required this.direction,
    required this.dayOfMonth,
    required this.startMonth,
    required this.category,
  });

  factory SeedRecurringTransaction.fromJson(Map<String, dynamic> json) {
    return SeedRecurringTransaction(
      name: json['name'] as String? ?? '',
      amountCents: json['amount_cents'] as int? ?? 0,
      direction: json['direction'] as String? ?? 'out',
      dayOfMonth: json['day_of_month'] as int? ?? 1,
      startMonth: json['start_month'] as String? ?? '2026-01',
      category: json['category'] as String? ?? 'other',
    );
  }
}

class SeedInitialTransaction {
  final String date;
  final int amountCents;
  final String direction;
  final String status;
  final String category;
  final String? note;

  SeedInitialTransaction({
    required this.date,
    required this.amountCents,
    required this.direction,
    required this.status,
    required this.category,
    this.note,
  });

  factory SeedInitialTransaction.fromJson(Map<String, dynamic> json) {
    return SeedInitialTransaction(
      date: json['date'] as String? ?? '',
      amountCents: json['amount_cents'] as int? ?? 0,
      direction: json['direction'] as String? ?? 'in',
      status: json['status'] as String? ?? 'actual',
      category: json['category'] as String? ?? 'income',
      note: json['note'] as String?,
    );
  }
}
