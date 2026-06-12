import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/calendar_screen.dart';
import '../../features/calendar/day_detail_screen.dart';
import '../../features/lists/lists_screen.dart';
import '../../features/meals/meals_screen.dart';
import '../../features/meals/recipe_edit_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/partner/partner_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/track/track_screen.dart';
import '../../features/trips/travel_planner_screen.dart';
import '../../features/trips/trip_detail_screen.dart';
import '../../features/trips/trip_edit_sheet.dart';
import '../design/design.dart';
import 'routes.dart';
import 'shell_scaffold.dart';

/// Extension point: agents 2-5 register extra routes here.
/// Keep the list sorted by feature area.
final List<RouteBase> agentRoutes = [
  GoRoute(path: '/trips', builder: (_, _) => const TravelPlannerScreen()),
  GoRoute(path: '/trips/new', builder: (_, _) => const TripEditSheet()),
  GoRoute(
    path: '/trips/:id',
    builder: (_, s) => TripDetailScreen(tripId: int.parse(s.pathParameters['id']!)),
  ),
  GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
  GoRoute(path: '/partner', builder: (_, _) => const PartnerScreen()),
  GoRoute(path: '/meals', builder: (_, _) => const MealsScreen()),
  GoRoute(path: '/recipes', builder: (_, _) => const RecipesScreen()),
  GoRoute(path: '/recipe/new', builder: (_, _) => const RecipeEditScreen()),
  GoRoute(
    path: '/recipe/:id',
    builder: (_, s) => RecipeEditScreen(existingId: int.parse(s.pathParameters['id']!)),
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
      builder: (context, state) =>
          _stubScreen(context, 'Collection ${state.pathParameters['id']}'),
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
