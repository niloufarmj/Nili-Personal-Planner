import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import 'gym_repository.dart';
import 'gym_session_log_sheet.dart';

class GymExercise {
  final String name;
  final String sets;
  final String reps;
  final String rest;
  final String? note;
  final bool isSuperset;

  const GymExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.rest,
    this.note,
    this.isSuperset = false,
  });
}

class Month3Plan {
  final String id;
  final String letter;
  final String title;
  final String subtitle;
  final String badge;
  final String warmup;
  final String cardio;
  final List<GymExercise> exercises;
  final Color themeColor;

  const Month3Plan({
    required this.id,
    required this.letter,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.warmup,
    required this.cardio,
    required this.exercises,
    required this.themeColor,
  });
}

final month3Plans = [
  const Month3Plan(
    id: 'A',
    letter: 'A',
    title: 'Glute & Hamstring Focus',
    subtitle: 'باسن + هامسترینگ + کور قوی',
    badge: '🔥 فاز ۳: باسن و هامسترینگ',
    themeColor: DesignTokens.rose,
    warmup: '🔆 پروتکل فعال‌سازی باسن (۱۰ دقیقه):\nمینی‌باند: ۲۰ Clamshell + ۲۰ Side Step + ۱۵ Glute Bridge با باند + ۱۰ Donkey Kick هر طرف',
    cardio: '⚡ HIIT ۲۰ دقیقه: Stairmaster یا بایسیکل — ۴۰ ثانیه توان / ۲۰ ثانیه استراحت',
    exercises: [
      GymExercise(
        name: 'Barbell Hip Thrust',
        sets: '۵ ست',
        reps: '۸–۱۰ تکرار',
        rest: '۱۲۰ ثانیه',
        note: 'وزن سنگین — آخرین ست تا حد خستگی. مهم‌ترین حرکت برای حجم باسن',
      ),
      GymExercise(
        name: 'اسکوات پهن (Sumo Squat) هالتر',
        sets: '۴ ست',
        reps: '۱۰ تکرار',
        rest: '۱۲۰ ثانیه',
        note: 'پنجه‌ها به سمت بیرون — تمرکز کامل روی باسن',
      ),
      GymExercise(
        name: 'Romanian Deadlift (RDL) هالتر',
        sets: '۴ ست',
        reps: '۱۰ تکرار',
        rest: '۱۲۰ ثانیه',
        note: 'کمر صاف، کشش کامل هامسترینگ',
      ),
      GymExercise(
        name: 'Bulgarian Split Squat با وزنه',
        sets: '۳ ست',
        reps: '۱۰ هر پا',
        rest: '۹۰ ثانیه',
        note: 'تعادل و تمرکز روی پای جلو',
      ),
      GymExercise(
        name: 'Cable Kickback + Abductor (سوپرست)',
        sets: '۳ ست',
        reps: '۱۵ + ۲۰',
        rest: '۶۰ ثانیه',
        isSuperset: true,
        note: 'بدون استراحت بین دو حرکت',
      ),
      GymExercise(
        name: 'Lying Hamstring Curl دستگاه',
        sets: '۳ ست',
        reps: '۱۵ تکرار',
        rest: '۶۰ ثانیه',
      ),
      GymExercise(
        name: 'Hanging Leg Raise + Plank (سوپرست)',
        sets: '۳ ست',
        reps: '۱۵ + ۴۵ ثانیه',
        rest: '۶۰ ثانیه',
        isSuperset: true,
        note: 'تقویت کامل کور و بخش پایینی شکم',
      ),
    ],
  ),
  const Month3Plan(
    id: 'B',
    letter: 'B',
    title: 'Back & Shoulder Sculpt',
    subtitle: 'پشت قوی، شانه متناسب، پاسچر ایده‌آل',
    badge: '✨ پاسچر + فرم‌دهی پشت و شانه',
    themeColor: DesignTokens.sage,
    warmup: '🔆 پروتکل پاسچر (۸ دقیقه):\n۲۰ Band Pull Apart + ۱۰ Wall Angel + ۱۰ Thoracic Extension روی فوم رولر',
    cardio: '🚶 Incline Walk ۲۵ دقیقه — شیب ۱۰–۱۲٪، سرعت ۵–۶ km/h (یا ۲۰ دقیقه Stairmaster)',
    exercises: [
      GymExercise(
        name: 'Weighted / Assisted Pull-up',
        sets: '۴ ست',
        reps: '۸–۱۲ تکرار',
        rest: '۱۲۰ ثانیه',
        note: 'یا Lat Pulldown سنگین — کشش کامل عضلات پشت',
      ),
      GymExercise(
        name: 'Barbell Row خم',
        sets: '۴ ست',
        reps: '۱۰ تکرار',
        rest: '۱۲۰ ثانیه',
        note: 'آرنج‌ها نزدیک بدن — انقباض کامل پشت',
      ),
      GymExercise(
        name: 'Meadows Row (دمبل تک دست با زاویه)',
        sets: '۳ ست',
        reps: '۱۲ هر طرف',
        rest: '۹۰ ثانیه',
      ),
      GymExercise(
        name: 'Straight Arm Pulldown کابل',
        sets: '۳ ست',
        reps: '۱۵ تکرار',
        rest: '۶۰ ثانیه',
        note: 'برای Lat و پهن شدن پشت',
      ),
      GymExercise(
        name: 'Dumbbell Push Press',
        sets: '۴ ست',
        reps: '۸ تکرار',
        rest: '۱۲۰ ثانیه',
        note: 'قدرت و حجم شانه',
      ),
      GymExercise(
        name: 'Face Pull + Lateral Raise (سوپرست اجباری)',
        sets: '۴ ست',
        reps: '۲۰ + ۱۵',
        rest: '۶۰ ثانیه',
        isSuperset: true,
        note: 'هر جلسه B باید این حرکت باشه — خیلی مهم برای اصلاح قوز',
      ),
      GymExercise(
        name: 'بک اکستنشن با صفحه وزنه',
        sets: '۳ ست',
        reps: '۱۵ تکرار',
        rest: '۶۰ ثانیه',
        note: 'تقویت فیله کمر',
      ),
    ],
  ),
  const Month3Plan(
    id: 'C',
    letter: 'C',
    title: 'Full Upper Body Power',
    subtitle: 'سینه، بازو، کور — حجم و قدرت ترکیبی',
    badge: '⚡ بالاتنه ترکیبی + بازو و کور',
    themeColor: DesignTokens.dustyBlue,
    warmup: '🔆 گرم کردن (۸ دقیقه):\n۱۵ Push-up + ۱۰ Inchworm + کشش شانه و سینه ۳۰ ثانیه',
    cardio: '🔥 Finisher: ۱۵ دقیقه HIIT روی Rower یا Bike (چربی‌سوز عالی)',
    exercises: [
      GymExercise(
        name: 'Barbell Bench Press تخت',
        sets: '۴ ست',
        reps: '۸–۱۰ تکرار',
        rest: '۱۲۰ ثانیه',
        note: 'حرکت اصلی سینه',
      ),
      GymExercise(
        name: 'Incline Dumbbell Press',
        sets: '۳ ست',
        reps: '۱۰–۱۲ تکرار',
        rest: '۹۰ ثانیه',
        note: 'تمرکز روی بخش بالای سینه',
      ),
      GymExercise(
        name: 'Cable Fly (Low to High)',
        sets: '۳ ست',
        reps: '۱۵ تکرار',
        rest: '۶۰ ثانیه',
      ),
      GymExercise(
        name: 'EZ Bar Curl + Skull Crusher (سوپرست)',
        sets: '۴ ست',
        reps: '۱۰ + ۱۰',
        rest: '۶۰ ثانیه',
        isSuperset: true,
        note: 'سوپرست جلو بازو + پشت بازو',
      ),
      GymExercise(
        name: 'Concentration Curl + Dip دستگاه (سوپرست)',
        sets: '۳ ست',
        reps: '۱۲ + ۱۲',
        rest: '۶۰ ثانیه',
        isSuperset: true,
        note: 'ایزولیشن بازو',
      ),
      GymExercise(
        name: 'Cable Woodchop (بالا به پایین)',
        sets: '۳ ست',
        reps: '۱۵ هر طرف',
        rest: '۶۰ ثانیه',
        note: 'مورب‌های شکم',
      ),
      GymExercise(
        name: 'Ab Wheel + Hollow Body Hold (سوپرست)',
        sets: '۳ ست',
        reps: '۱۲ + ۳۰ ثانیه',
        rest: '۶۰ ثانیه',
        isSuperset: true,
        note: 'فینیشر کامل کور',
      ),
    ],
  ),
];

class GymProgramGuideScreen extends ConsumerStatefulWidget {
  const GymProgramGuideScreen({super.key});

  @override
  ConsumerState<GymProgramGuideScreen> createState() => _GymProgramGuideScreenState();
}

class _GymProgramGuideScreenState extends ConsumerState<GymProgramGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: month3Plans.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gym Program Guide',
          style: theme.textTheme.headlineLarge?.copyWith(color: inkColor),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          indicatorColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
          tabs: month3Plans
              .map((p) => Tab(text: 'Plan ${p.letter}'))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: month3Plans.map((plan) => _buildPlanView(plan, isDark, theme)).toList(),
      ),
    );
  }

  Widget _buildPlanView(Month3Plan plan, bool isDark, ThemeData theme) {
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Header Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: plan.themeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        plan.letter,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: plan.themeColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                        Text(
                          plan.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: plan.themeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  plan.badge,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: plan.themeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Warmup Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 20, color: DesignTokens.peach),
                  const SizedBox(width: 8),
                  Text(
                    'Warmup Protocol',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: inkColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.warmup,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section Title: Exercises
        Text(
          'Exercises (${plan.exercises.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 8),

        // Exercises List
        ...plan.exercises.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final ex = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? DesignTokens.surfaceDark : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$idx',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ex.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                      ),
                      if (ex.isSuperset)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: DesignTokens.rose.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Superset',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: DesignTokens.rose,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildChip(ex.sets, DesignTokens.dustyBlue, isDark),
                      _buildChip(ex.reps, DesignTokens.sage, isDark),
                      _buildChip('Rest: ${ex.rest}', DesignTokens.butter, isDark),
                    ],
                  ),
                  if (ex.note != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '• ${ex.note}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 8),
        // Cardio Finisher Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_run, size: 20, color: DesignTokens.rose),
                  const SizedBox(width: 8),
                  Text(
                    'Cardio & Finisher',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: inkColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.cardio,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Log Today Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: plan.themeColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: Text('Log Today\'s Plan ${plan.letter} Session'),
          onPressed: () async {
            final repo = ref.read(workoutPlanRepositoryProvider);
            final plans = await repo.watchAll().first;
            final match = plans.firstWhere(
              (p) => p.name == plan.letter,
              orElse: () => plans.first,
            );
            if (context.mounted) {
              final nowStr = DateTime.now().toIso8601String().split('T').first;
              GymSessionLogSheet.show(context, date: nowStr, plannedPlanId: match.id);
            }
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildChip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? DesignTokens.adjustColorForDark(color) : color,
        ),
      ),
    );
  }
}
