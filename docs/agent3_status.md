# Agent 3 — Finance · Work Time · Social: Status

## Done

### Finance
- `TransactionRepository` — CRUD, `watchByMonth`, `getByMonth`, `getByDate`
- `RecurringRepository` — CRUD, `expandForMonth` (clamps day-of-month, respects start/end month)
- `DebtRepository` — CRUD, settle / reopen flow
- `ForecastService` — actual + projected + planned balance; category breakdown
- `CurrencyFormatter` — integer-cent formatting / parsing; re-exported from `design.dart`
- `FinanceScreen` — month pager with `PageView`, forecast card, transaction list
- `ForecastCard` — end-of-month balance card (FutureProvider, no stream)
- `QuickAddSheet` — modal bottom sheet to add a transaction
- `TransactionTile` — planned→actual conversion on tap
- Calendar integration — `financeDots` field added to `CalendarDayData`; `CalendarAggregator` populates it from planned transactions in range
- `ExpenseLinkService` — `createFromItem` / `markBought`; links shopping items to transactions via `note = 'item:$itemId'`
- `docs/contracts.md` §12 (CurrencyFormatter) and §13 (ExpenseLinkService) added
- `TrackScreen` replaced stub with real navigation ListView (Finance, Work Time, Social, Gym, Fitness, Habits, Feeling Better, Meals entries)

### Work Time
- `WorktimeRepository` — context CRUD, time-entry CRUD, `startTimer` / `stopTimer`, `getTotalMinutesForDate/Week`, `getMinutesPerContextForMonth`, baseline hours (AppSettings)
- `RollupService` — `compute(month)` → `savedDays`; `formatMinutes`
- `WorktimeScreen` — context list, timer widget, monthly rollup card
- `TimerWidget` — shows running timer with start/stop

### Social
- `SocialRepository` — account CRUD, log CRUD, `computeStreak`, `daysAgoLastPost`, `weeklyMinutes`
- `SocialScreen` — account cards with streak badge, quick-log FAB
- `SocialLogSheet` — modal to add a post/browse/story log

### Tests — all green (59 / 59)
- `test/features/finance/repositories_test.dart` — 13 tests
- `test/features/finance/forecast_service_test.dart` — 8 tests
- `test/features/finance/calendar_integration_test.dart` — 3 tests
- `test/features/finance/widget_test.dart` — 3 widget tests
- `test/features/worktime/rollup_test.dart` — 12 tests
- `test/features/social/social_test.dart` — 15 tests
- `test/core/services/expense_link_service_test.dart` — 5 tests

### Quality
- `flutter analyze` — 0 issues
- `dart format .` — applied

---

## Missing / Not Done

### Finance
- **DebtScreen** — no dedicated screen to view/manage debts; `FinanceScreen` only shows transactions
- **Recurring transactions UI** — no way to create/edit recurring entries from the UI; repository is complete but no screen
- **Charts tab** — `FinanceScreen` month view has no spend-by-category bar chart (fl_chart added to pubspec but chart widget not implemented)
- **Budget limits** — no per-category budget cap feature

### Work Time
- **WorktimeScreen deep-link** — `/worktime` route is wired in `agentRoutes` but the screen navigation from TrackScreen is not tested end-to-end
- **Context selector on timer** — `TimerWidget` starts timer without a context picker; user can't switch context mid-session from the UI

### Social
- **Account edit/delete UI** — `SocialRepository` supports it but no UI action on `SocialScreen`
- **Weekly minutes chart** — `weeklyMinutes` aggregation exists but no chart widget in `SocialScreen`

### Nav-shell test failures (pre-existing, not regressions)
The following 4 `nav_shell_test.dart` tests fail with a Drift pending-timer error caused by stream providers in other agents' screens (ListsScreen, TodayScreen) being disposed at test teardown. These are **not regressions from Agent 3's code** — TrackScreen is a pure `StatelessWidget` with no providers:
- `Tap Lists tab navigates to ListsScreen`
- `Tap Track tab navigates to TrackScreen`
- `Tap More tab navigates to MoreScreen`
- `No exceptions across all 5 tabs`
