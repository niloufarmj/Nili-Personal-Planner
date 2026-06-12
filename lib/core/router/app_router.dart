import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/calendar_screen.dart';
import '../../features/calendar/day_detail_screen.dart';
import '../../features/finance/charts_screen.dart';
import '../../features/finance/debts_screen.dart';
import '../../features/finance/finance_screen.dart';
import '../../features/finance/recurring_screen.dart';
import '../../features/gym/gym_screen.dart';
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
import '../../features/worktime/worktime_screen.dart';
import '../design/design.dart';
import 'routes.dart';
import 'shell_scaffold.dart';

/// Extension point: agents 2-5 register extra routes here.
/// Keep the list sorted by feature area.
final List<RouteBase> agentRoutes = [
  // Finance
  GoRoute(path: '/finance', builder: (context, state) => const FinanceScreen()),
  GoRoute(
    path: '/finance/charts',
    builder: (context, state) {
      final month = (state.extra as DateTime?) ?? DateTime.now();
      return ChartsScreen(month: month);
    },
  ),
  GoRoute(
    path: '/finance/recurring',
    builder: (context, state) => const RecurringScreen(),
  ),
  GoRoute(
    path: '/finance/debts',
    builder: (context, state) => const DebtsScreen(),
  ),
  // Gym
  GoRoute(path: '/gym', builder: (context, state) => const GymScreen()),
  // Fitness, Habits, Wellbeing — registered by their screens (stubs until Step 3-6)
  GoRoute(
    path: '/fitness',
    builder: (context, state) => _stubScreen(context, 'Fitness'),
  ),
  GoRoute(
    path: '/habits',
    builder: (context, state) => _stubScreen(context, 'Habits'),
  ),
  GoRoute(
    path: '/wellbeing',
    builder: (context, state) => _stubScreen(context, 'Feeling Better'),
  ),
  // Work time
  GoRoute(
    path: '/worktime',
    builder: (context, state) => const WorktimeScreen(),
  ),
  // Social
  GoRoute(path: '/social', builder: (context, state) => const SocialScreen()),
  // Trips
  GoRoute(
    path: '/trips',
    builder: (context, state) => const TravelPlannerScreen(),
  ),
  GoRoute(
    path: '/trips/new',
    builder: (context, state) => const TripEditSheet(),
  ),
  GoRoute(
    path: '/trips/:id',
    builder: (context, state) =>
        TripDetailScreen(tripId: int.parse(state.pathParameters['id']!)),
  ),
  // Reminders
  GoRoute(
    path: '/reminders',
    builder: (context, state) => const RemindersScreen(),
  ),
  // Partner
  GoRoute(path: '/partner', builder: (context, state) => const PartnerScreen()),
  // Meals
  GoRoute(path: '/meals', builder: (context, state) => const MealsScreen()),
  GoRoute(path: '/recipes', builder: (context, state) => const RecipesScreen()),
  GoRoute(
    path: '/recipe/new',
    builder: (context, state) => const RecipeEditScreen(),
  ),
  GoRoute(
    path: '/recipe/:id',
    builder: (context, state) =>
        RecipeEditScreen(existingId: int.parse(state.pathParameters['id']!)),
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
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.calendar,
              builder: (context, state) => const CalendarScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.lists,
              builder: (context, state) => const ListsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.track,
              builder: (context, state) => const TrackScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.more,
              builder: (context, state) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),
    // Deep-link routes (outside the shell, full-screen)
    GoRoute(
      path: Routes.dayDetail,
      builder: (context, state) =>
          DayDetailScreen(date: state.pathParameters['date']!),
    ),
    GoRoute(
      path: Routes.collection,
      builder: (context, state) => CollectionScreen(
        collectionId: int.parse(state.pathParameters['id']!),
      ),
    ),
    ...agentRoutes,
  ],
);

final GoRouter appRouter = buildAppRouter();

Widget _stubScreen(BuildContext context, String title) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: EmptyState(
    icon: Icons.construction,
    message: '$title — coming soon',
    hint: 'This screen will be filled by another agent.',
  ),
);
