import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';

import '../../features/calendar/calendar_screen.dart';
import '../../features/calendar/day_detail_screen.dart';
import '../../features/finance/charts_screen.dart';
import '../../features/finance/debts_screen.dart';
import '../../features/finance/finance_screen.dart';
import '../../features/finance/recurring_screen.dart';
import '../../features/fitness/fitness_screen.dart';
import '../../features/gym/gym_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/lists/lists_screen.dart';
import '../../features/lists/screens/collection_screen.dart';
import '../../features/meals/meals_screen.dart';
import '../../features/meals/recipe_edit_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/partner/partner_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/social/social_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/track/track_screen.dart';
import '../../features/trips/travel_planner_screen.dart';
import '../../features/trips/trip_detail_screen.dart';
import '../../features/trips/trip_edit_sheet.dart';
import '../../features/wellbeing/wellbeing_screen.dart';
import '../../features/worktime/worktime_screen.dart';
import '../design/styleguide_screen.dart';
import 'routes.dart';
import 'shell_scaffold.dart';

/// Helper to wrap a widget builder with a 200ms fade-through transition.
Page<dynamic> _fadeThroughPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}

/// Extension point: agents 2-5 register extra routes here.
/// Keep the list sorted by feature area.
final List<RouteBase> agentRoutes = [
  // Finance
  GoRoute(
    path: '/finance',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const FinanceScreen(),
    ),
  ),
  GoRoute(
    path: '/finance/charts',
    pageBuilder: (context, state) {
      final month = (state.extra as DateTime?) ?? DateTime.now();
      return _fadeThroughPage(
        context: context,
        state: state,
        child: ChartsScreen(month: month),
      );
    },
  ),
  GoRoute(
    path: '/finance/recurring',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const RecurringScreen(),
    ),
  ),
  GoRoute(
    path: '/finance/debts',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const DebtsScreen(),
    ),
  ),
  // Gym
  GoRoute(
    path: '/gym',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const GymScreen(),
    ),
  ),
  // Fitness, Habits, Wellbeing
  GoRoute(
    path: '/fitness',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const FitnessScreen(),
    ),
  ),
  GoRoute(
    path: '/habits',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const HabitsScreen(),
    ),
  ),
  GoRoute(
    path: '/wellbeing',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const WellbeingScreen(),
    ),
  ),
  // Work time
  GoRoute(
    path: '/worktime',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const WorktimeScreen(),
    ),
  ),
  // Social
  GoRoute(
    path: '/social',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const SocialScreen(),
    ),
  ),
  // Trips
  GoRoute(
    path: '/trips',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const TravelPlannerScreen(),
    ),
  ),
  GoRoute(
    path: '/trips/new',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const TripEditSheet(),
    ),
  ),
  GoRoute(
    path: '/trips/:id',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: TripDetailScreen(tripId: int.parse(state.pathParameters['id']!)),
    ),
  ),
  // Reminders
  GoRoute(
    path: '/reminders',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const RemindersScreen(),
    ),
  ),
  // Partner
  GoRoute(
    path: '/partner',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const PartnerScreen(),
    ),
  ),
  // Meals
  GoRoute(
    path: '/meals',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const MealsScreen(),
    ),
  ),
  GoRoute(
    path: '/recipes',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const RecipesScreen(),
    ),
  ),
  GoRoute(
    path: '/recipe/new',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const RecipeEditScreen(),
    ),
  ),
  GoRoute(
    path: '/recipe/:id',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: RecipeEditScreen(
        existingId: int.parse(state.pathParameters['id']!),
      ),
    ),
  ),
  // Debug
  GoRoute(
    path: '/debug/styleguide',
    pageBuilder: (context, state) => _fadeThroughPage(
      context: context,
      state: state,
      child: const StyleguideScreen(),
    ),
  ),
];

/// Creates a fresh [GoRouter]. Use this in tests so each test gets isolated
/// navigation state; [appRouter] is the singleton used by the running app.
GoRouter buildAppRouter() => GoRouter(
  initialLocation: Routes.today,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.today,
              pageBuilder: (context, state) => _fadeThroughPage(
                context: context,
                state: state,
                child: const TodayScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.calendar,
              pageBuilder: (context, state) => _fadeThroughPage(
                context: context,
                state: state,
                child: const CalendarScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.lists,
              pageBuilder: (context, state) => _fadeThroughPage(
                context: context,
                state: state,
                child: const ListsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.track,
              pageBuilder: (context, state) => _fadeThroughPage(
                context: context,
                state: state,
                child: const TrackScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.more,
              pageBuilder: (context, state) => _fadeThroughPage(
                context: context,
                state: state,
                child: const MoreScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    // Deep-link routes (outside the shell, full-screen)
    GoRoute(
      path: Routes.dayDetail,
      pageBuilder: (context, state) => _fadeThroughPage(
        context: context,
        state: state,
        child: DayDetailScreen(date: state.pathParameters['date']!),
      ),
    ),
    GoRoute(
      path: Routes.collection,
      pageBuilder: (context, state) => _fadeThroughPage(
        context: context,
        state: state,
        child: CollectionScreen(
          collectionId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ),
    ...agentRoutes,
  ],
);

final GoRouter appRouter = buildAppRouter();
