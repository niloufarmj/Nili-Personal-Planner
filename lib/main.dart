import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/database.dart';
import 'core/db/repositories/day_repository.dart';
import 'core/design/design.dart';
import 'core/router/app_router.dart';
import 'features/gym/gym_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();

  // One-time seeds (idempotent)
  await DayRepository(db).seedDefaultTagsIfNeeded();
  await WorkoutPlanRepository(db).seedDefaultPlansIfNeeded();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const PersonalPlannerApp(),
    ),
  );
}

class PersonalPlannerApp extends StatelessWidget {
  const PersonalPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Personal Planner',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
