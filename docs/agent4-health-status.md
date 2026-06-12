# Agent 4 — Health Features: Status

Branch: `feat/health`

## Done

### Step 1 ✅ `feat(gym): plans and session logging` (committed: c26420e)
- `lib/features/gym/gym_repository.dart` — `WorkoutPlanRepository` + `GymRepository`
  - `watchAll`, `get`, `create`, `update`, `delete`, `seedDefaultPlansIfNeeded` (seeds A/B/C idempotently)
  - `watchUpcoming`, `watchHistory`, `sessionForDate`, `planSession`, `logDone`, `markMissedSessions`, `doneCountForWeek`
  - Providers: `workoutPlanRepositoryProvider`, `gymRepositoryProvider`
- `test/features/gym/gym_repository_test.dart` — 15 passing unit tests

### Step 2 ✅ `feat(gym): screens and calendar dots` (staged, not yet committed)
- `lib/features/gym/gym_screen.dart` — `GymScreen` + `DayDetailGymSection`
  - Week-stat card with progress bar, upcoming sessions list, history list
  - Travel-day warning (reads day tags), planned/done/missed session tiles
  - All providers defined at top-level (no inline providers — fixes Riverpod rebuild loop)
- `lib/features/gym/gym_session_log_sheet.dart` — bottom-sheet log with plan picker, duration stepper, notes
- `lib/features/gym/workout_plan_screen.dart` — plan list + inline editor
- `lib/features/calendar/calendar_screen.dart` — gym dots: filled=done, outlined=planned, faded=missed
- `lib/features/calendar/day_detail_screen.dart` — `DayDetailGymSection` wired in
- `lib/features/track/track_screen.dart` — Gym, Fitness, Habits, Feeling Better entries added
- `lib/main.dart` — `seedDefaultPlansIfNeeded` called on startup
- `test/features/gym/gym_widget_test.dart` — 5 widget tests (all green)
  - Includes fix for Drift+Riverpod+flutter_test pending-timer invariant

## Not Yet Done

### Step 3 ❌ `feat(fitness): measurements, photos, charts, goals`
- `lib/features/fitness/fitness_repository.dart`
  - Body measurements CRUD (weight, body fat %, etc.) with JSON fields
  - Progress photos via `ImageService`
  - Fitness goals CRUD with achievement detection (up/down direction)
  - Weekly + monthly reminders (NotificationService IDs 241–242)
- `lib/features/fitness/` screens — charts (fl_chart), goals, photo gallery
- `/fitness` route (currently a stub in app_router.dart)
- `fl_chart` dependency in pubspec.yaml
- `direction` column migration for `fitness_goals` table (schema v2)
- Tests: goal achievement (up/down), JSON round-trip, chart series mapping, reminder scheduling

### Step 4 ❌ `feat(habits): counters and batched reminders`
- `lib/features/habits/habit_repository.dart`
  - `increment`/`decrement` (never-negative count), `watchToday`, streaks
  - Seeded defaults: Water/8, Skincare AM, Skincare PM, Teeth/2, Reading
  - Batched reminders at 09:00/13:00/17:00/21:00 (NotificationService IDs 200–240)
- `lib/features/habits/` screens — habit manager UI
- `/habits` route (currently a stub)
- `lib/main.dart` — habit seeding on startup
- Tests

### Step 5 ❌ `feat(habits): today tap counters`
- `lib/features/today/today_screen.dart` — replace `_AgentPlaceholder('Habit tracker — agent 4')` with:
  - Habit chip row: tap=+1, long-press=−1, water shows 3/8 progress
  - Gym quick-done button
  - Haptic feedback + count animation
- Widget tests

### Step 6 ❌ `feat(wellbeing): actions and history`
- `lib/features/wellbeing/wellbeing_repository.dart`
  - `log`/`unlog` actions (idempotent), heat-map data query
  - Seeded defaults: meditation, talk to friend, listen to music
- `lib/features/wellbeing/` screens — action checklist + heat calendar (7×52 grid)
- `/wellbeing` route (currently a stub)
- `lib/main.dart` — wellbeing seeding on startup
- Tests: log/unlog idempotency, heat-map mapping, custom action CRUD

## Key Notes for Whoever Continues

- **Notification IDs 200–299** are reserved for health features (200–240 habits, 241–242 fitness)
- **Schema version** is currently 1; fitness goals `direction` column needs migration to v2 in `onUpgrade`
- **Riverpod rule**: never create `Provider(...)` inline inside `build()` — always top-level or `.family`; inline providers cause infinite rebuild loops
- **Drift+flutter_test**: `StreamProvider.autoDispose` backed by Drift streams creates 0-duration timers during disposal. Call `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 100));` at the END of each `testWidgets` body that uses such screens (before the framework's own cleanup at `_runTestBody:1689`).
- `/fitness`, `/habits`, `/wellbeing` routes are stubs in `app_router.dart`
- Today screen placeholder for habits: `_AgentPlaceholder('Habit tracker — agent 4')` in `lib/features/today/today_screen.dart`
