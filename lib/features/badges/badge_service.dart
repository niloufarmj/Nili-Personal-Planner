import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

class BadgeInfo {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final String unlockProgress;
  final double progress;

  BadgeInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.unlockProgress,
    required this.progress,
  });
}

final earnedBadgesProvider = FutureProvider.autoDispose<List<BadgeInfo>>((ref) async {
  final db = ref.watch(appDatabaseProvider);

  // 1. Fetch active habits & logs
  final habits = await (db.select(db.habits)..where((h) => h.active.equals(true))).get();
  final habitLogs = await db.select(db.habitLogs).get();

  // 2. Fetch completed tasks
  final completedTasks = await (db.select(db.items)..where((i) => i.status.equals('done'))).get();
  final completedCount = completedTasks.length;

  // 3. Fetch achieved goals
  final achievedGoals = await (db.select(db.fitnessGoals)..where((g) => g.achievedDate.isNotNull())).get();
  final achievedGoalsCount = achievedGoals.length;

  // 4. Fetch social media posts
  final socialLogs = await (db.select(db.socialLogs)..where((l) => l.activity.equals('post'))).get();
  final socialCount = socialLogs.length;

  // 5. Fetch completed gym sessions
  final gymSessions = await (db.select(db.gymSessions)..where((s) => s.status.equals('done'))).get();
  final gymCount = gymSessions.length;

  // 6. Fetch job hunt applications (collections with template 'job', and items not in 'researching' status)
  final collections = await db.select(db.collections).get();
  final jobCollectionIds = collections.where((c) => c.template == 'job').map((c) => c.id).toSet();
  final jobItems = await db.select(db.items).get();
  final appliedJobsCount = jobItems.where((item) => jobCollectionIds.contains(item.collectionId) && item.status != 'researching').length;

  // 7. Fetch wellbeing self-care logs
  final wellbeingLogs = await db.select(db.wellbeingLogs).get();
  final wellbeingCount = wellbeingLogs.length;

  // 8. Fetch eaten meals
  final mealSlots = await (db.select(db.mealSlots)..where((s) => s.status.equals('eaten'))).get();
  final eatenMealsCount = mealSlots.length;

  // 9. Fetch time entries and compute work hours
  final workEntries = await db.select(db.timeEntries).get();
  final totalWorkMinutes = workEntries.fold<int>(0, (sum, entry) => sum + entry.minutes);
  final totalWorkHours = totalWorkMinutes / 60.0;

  // Calculate habit streak (max streak of days where ALL active habits were completed)
  int habitMaxStreak = 0;
  if (habits.isNotEmpty) {
    final Map<String, List<HabitLog>> logsByDate = {};
    for (final log in habitLogs) {
      logsByDate.putIfAbsent(log.date, () => []).add(log);
    }

    final dates = logsByDate.keys.toList()..sort();
    int currentStreak = 0;

    for (final dateStr in dates) {
      final dayLogs = logsByDate[dateStr] ?? [];
      bool allMet = true;

      for (final h in habits) {
        final log = dayLogs.where((l) => l.habitId == h.id).firstOrNull;
        if (log == null || log.count < h.targetPerDay) {
          allMet = false;
          break;
        }
      }

      if (allMet) {
        currentStreak++;
        if (currentStreak > habitMaxStreak) {
          habitMaxStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }
  }

  return [
    // Habits Streaks
    BadgeInfo(
      id: 'habit_streak_10',
      title: 'Habit Novice',
      description: 'Keep a perfect streak on all active habits for 10 days.',
      icon: Icons.water_drop,
      color: Colors.blue[300]!,
      isUnlocked: habitMaxStreak >= 10,
      unlockProgress: '$habitMaxStreak / 10 days',
      progress: (habitMaxStreak / 10.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'habit_streak_50',
      title: 'Habit Champion',
      description: 'Keep a perfect streak on all active habits for 50 days.',
      icon: Icons.insights,
      color: Colors.orange[400]!,
      isUnlocked: habitMaxStreak >= 50,
      unlockProgress: '$habitMaxStreak / 50 days',
      progress: (habitMaxStreak / 50.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'habit_streak_100',
      title: 'Habit Legend',
      description: 'Keep a perfect streak on all active habits for 100 days.',
      icon: Icons.stars,
      color: Colors.amber[600]!,
      isUnlocked: habitMaxStreak >= 100,
      unlockProgress: '$habitMaxStreak / 100 days',
      progress: (habitMaxStreak / 100.0).clamp(0.0, 1.0),
    ),

    // Tasks Completed
    BadgeInfo(
      id: 'tasks_10',
      title: 'Task Solver',
      description: 'Mark 10 list items or planner tasks as done.',
      icon: Icons.checklist,
      color: Colors.purple[300]!,
      isUnlocked: completedCount >= 10,
      unlockProgress: '$completedCount / 10 tasks',
      progress: (completedCount / 10.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'tasks_50',
      title: 'Task Master',
      description: 'Mark 50 list items or planner tasks as done.',
      icon: Icons.assignment_turned_in,
      color: Colors.indigo[400]!,
      isUnlocked: completedCount >= 50,
      unlockProgress: '$completedCount / 50 tasks',
      progress: (completedCount / 50.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'tasks_100',
      title: 'Task Overlord',
      description: 'Mark 100 list items or planner tasks as done.',
      icon: Icons.military_tech,
      color: Colors.red[400]!,
      isUnlocked: completedCount >= 100,
      unlockProgress: '$completedCount / 100 tasks',
      progress: (completedCount / 100.0).clamp(0.0, 1.0),
    ),

    // Fitness Goals Achieved
    BadgeInfo(
      id: 'fitness_1',
      title: 'Goal Achiever',
      description: 'Achieve at least 1 custom fitness goal.',
      icon: Icons.emoji_events,
      color: Colors.teal[300]!,
      isUnlocked: achievedGoalsCount >= 1,
      unlockProgress: '$achievedGoalsCount / 1 goals',
      progress: (achievedGoalsCount / 1.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'fitness_3',
      title: 'Fitness Fanatic',
      description: 'Achieve at least 3 custom fitness goals.',
      icon: Icons.fitness_center,
      color: Colors.cyan[400]!,
      isUnlocked: achievedGoalsCount >= 3,
      unlockProgress: '$achievedGoalsCount / 3 goals',
      progress: (achievedGoalsCount / 3.0).clamp(0.0, 1.0),
    ),

    // Gym Sessions Completed
    BadgeInfo(
      id: 'gym_5',
      title: 'Gym Starter',
      description: 'Log 5 completed gym workout sessions.',
      icon: Icons.directions_run,
      color: Colors.blueAccent[200]!,
      isUnlocked: gymCount >= 5,
      unlockProgress: '$gymCount / 5 workouts',
      progress: (gymCount / 5.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'gym_20',
      title: 'Gym Regular',
      description: 'Log 20 completed gym workout sessions.',
      icon: Icons.fitness_center,
      color: Colors.blue[600]!,
      isUnlocked: gymCount >= 20,
      unlockProgress: '$gymCount / 20 workouts',
      progress: (gymCount / 20.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'gym_50',
      title: 'Iron Warrior',
      description: 'Log 50 completed gym workout sessions.',
      icon: Icons.offline_bolt,
      color: Colors.deepPurple[400]!,
      isUnlocked: gymCount >= 50,
      unlockProgress: '$gymCount / 50 workouts',
      progress: (gymCount / 50.0).clamp(0.0, 1.0),
    ),

    // Job Hunt Applications
    BadgeInfo(
      id: 'job_5',
      title: 'Applicant',
      description: 'Apply to 5 companies in your job hunt tracker.',
      icon: Icons.send,
      color: Colors.lightGreen[400]!,
      isUnlocked: appliedJobsCount >= 5,
      unlockProgress: '$appliedJobsCount / 5 applications',
      progress: (appliedJobsCount / 5.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'job_15',
      title: 'Job Hunter',
      description: 'Apply to 15 companies in your job hunt tracker.',
      icon: Icons.business_center,
      color: Colors.teal[400]!,
      isUnlocked: appliedJobsCount >= 15,
      unlockProgress: '$appliedJobsCount / 15 applications',
      progress: (appliedJobsCount / 15.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'job_30',
      title: 'Career Explorer',
      description: 'Apply to 30 companies in your job hunt tracker.',
      icon: Icons.explore,
      color: Colors.teal[800]!,
      isUnlocked: appliedJobsCount >= 30,
      unlockProgress: '$appliedJobsCount / 30 applications',
      progress: (appliedJobsCount / 30.0).clamp(0.0, 1.0),
    ),

    // Wellbeing Self-Care
    BadgeInfo(
      id: 'wellbeing_5',
      title: 'Mindfulness Seeker',
      description: 'Log 5 self-care or wellbeing actions.',
      icon: Icons.self_improvement,
      color: Colors.green[300]!,
      isUnlocked: wellbeingCount >= 5,
      unlockProgress: '$wellbeingCount / 5 actions',
      progress: (wellbeingCount / 5.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'wellbeing_20',
      title: 'Zen Master',
      description: 'Log 20 self-care or wellbeing actions.',
      icon: Icons.spa,
      color: Colors.green[600]!,
      isUnlocked: wellbeingCount >= 20,
      unlockProgress: '$wellbeingCount / 20 actions',
      progress: (wellbeingCount / 20.0).clamp(0.0, 1.0),
    ),

    // Healthy Eating
    BadgeInfo(
      id: 'meals_10',
      title: 'Healthy Eater',
      description: 'Log 10 eaten planned meals.',
      icon: Icons.restaurant,
      color: Colors.orange[300]!,
      isUnlocked: eatenMealsCount >= 10,
      unlockProgress: '$eatenMealsCount / 10 meals',
      progress: (eatenMealsCount / 10.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'meals_30',
      title: 'Meal Planner',
      description: 'Log 30 eaten planned meals.',
      icon: Icons.restaurant_menu,
      color: Colors.orange[600]!,
      isUnlocked: eatenMealsCount >= 30,
      unlockProgress: '$eatenMealsCount / 30 meals',
      progress: (eatenMealsCount / 30.0).clamp(0.0, 1.0),
    ),

    // Work Time
    BadgeInfo(
      id: 'work_10h',
      title: 'Hard Worker',
      description: 'Log 10 hours of work time.',
      icon: Icons.timer,
      color: Colors.blueGrey[300]!,
      isUnlocked: totalWorkHours >= 10,
      unlockProgress: '${totalWorkHours.toStringAsFixed(1)} / 10 hours',
      progress: (totalWorkHours / 10.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'work_50h',
      title: 'Deep Worker',
      description: 'Log 50 hours of work time.',
      icon: Icons.computer,
      color: Colors.blueGrey[600]!,
      isUnlocked: totalWorkHours >= 50,
      unlockProgress: '${totalWorkHours.toStringAsFixed(1)} / 50 hours',
      progress: (totalWorkHours / 50.0).clamp(0.0, 1.0),
    ),

    // Social Media Posts
    BadgeInfo(
      id: 'social_10',
      title: 'Social Butterfly',
      description: 'Create 10 posts or stories in social tracking.',
      icon: Icons.people,
      color: Colors.pink[300]!,
      isUnlocked: socialCount >= 10,
      unlockProgress: '$socialCount / 10 posts',
      progress: (socialCount / 10.0).clamp(0.0, 1.0),
    ),
    BadgeInfo(
      id: 'social_50',
      title: 'Influencer',
      description: 'Create 50 posts or stories in social tracking.',
      icon: Icons.campaign,
      color: Colors.deepOrange[400]!,
      isUnlocked: socialCount >= 50,
      unlockProgress: '$socialCount / 50 posts',
      progress: (socialCount / 50.0).clamp(0.0, 1.0),
    ),
  ];
});
