# Nili Personal Planner 🚀

A comprehensive, beautifully designed, and offline-first personal organizer built with Flutter. Nili Personal Planner integrates day-to-day agendas, modular tracking engines, recipe books, fitness records, social media logs, period forecasting, gamified achievements, and intelligent finance forecasting into a unified dashboard.

---

## 🌟 Core Modules & Features

### 📅 1. Planner & Calendar
*   **Day Tagging**: Personalize daily logs with custom tags, mood emojis, energy levels, and statuses.
*   **Month & Week Agenda Views**: Toggle between a month grid and a detailed vertical 7-day Week Agenda List displaying day row cards with scheduled events, location overlays, workouts, meals, due tasks, and cycle status.
*   **Filter Chips Bar**: Toggle overlays on/off in real-time (Location, Gym, Meals, Work, Uni, Travel, Social, Tasks, Partner, Reminders, and Period).
*   **Day Details & Action Sheets**: Tap any calendar day to inspect detailed sections for events, finance, meals, fitness, period logs, and chore deadlines.

### ☀️ 2. Today's Dashboard & Next 7 Days
*   **Daily Focus & Priorities**: Highlight key tasks and manage checklist priorities with gamified completion feedback.
*   **Hydration Tracker**: Keep count of daily water glass intake.
*   **Self-Care & Skincare Checklist**: Monitor AM/PM skincare routines, vitamin intake (multi-vitamin, vitamin D), and dental hygiene.
*   **7-Day Horizon Planner**: View upcoming deadlines, scheduled appointments, and tasks in a rolling weekly dashboard.

### 💰 3. Intelligent Finance & Forecasting
*   **Transactions Ledger**: Record actual income and expenses with tag support and categories.
*   **Auto-Syncing Subscriptions & Salary**: Pre-define salary transfers (e.g., 1250 on the 27th) and recurring subscriptions (Klimaticket, Internet, Claude, etc.). The background auto-sync engine automatically logs past-due items upon opening the app.
*   **Smart Balance Forecaster**: Displays real-time estimated balance subtitles when planning travel budgets or items:
    `"If you spend this, your estimated left balance on [Date] would be €[Amount]"`
    The engine integrates current actual balances, future planned income, future recurring bills, and a pro-rated mean of historical variable spends.
*   **Debts Center**: Track money owed (`i_owe`) or owed to you (`owes_me`). Supports interactive amount editing and auto-prompts to log matching payments/payoffs in your transaction ledger.

### 🎒 4. Lists, Chores & Collections
*   **Template-Driven Collections**: Create shopping lists, travel packing guides, custom todo lists, or job hunt trackers.
*   **Header Photos**: Set a custom cover photo per list from its own screen (⋮ menu). Shown as a banner atop the list and faintly behind its card in the Lists grid.
*   **Subtasks & Checklists**: Break down list items into smaller multi-step subtasks.
*   **Periodic Chores**: Log periodic tasks (cleaning, laundry, plant watering) with history logs.
*   **Shopping Actual Cost Prompts**: Mark items as "bought" to prompt for actual costs and automatically record them as shopping transactions.

### ✈️ 5. Smart Travel Planner
*   **Destinations & Budgets**: Detail travel periods, destination descriptions, and budgets.
*   **Packing Lists**: Generate packing lists linked directly to your travel dates.
*   **Forecast Integration**: Live forecaster computes whether your trip budget is sustainable based on future financial schedules.

### 🥩 6. Meal Planner & Recipe Book
*   **Ingredient Catalog**: Manage pantry supplies, measuring units, quantities, calories, protein, estimated costs, and custom ingredient photo avatars.
*   **Recipe Creator**: Detail recipes, prep times, cooking steps, and list ingredient mappings.
*   **Weekly Meal Slot Board**: Plan weekly breakfasts, lunches, dinners, and post-gym shakes.
*   **Groceries List Sync & Missing Ingredient Alerts**: Integrated directly with your Groceries collection in the Lists tab. Automatically cross-checks planned meal ingredients against stock status, alerts for missing items (`⚠️ Need: Cucumber, Toast`), and populates items into your Groceries shopping list.
*   **3 Stock Filter Tabs**: Filter Groceries list by `All`, `Need to buy 🛒`, and `In stock ✅` with 1-tap stock status toggling and small circular ingredient photo avatars.

### 🏋️ 7. Gym, Sports & Fitness Tracker
*   **Multi-Sport Activity Logging**: Log sessions across Swimming 🏊, Tennis 🎾, Biking 🚴, Running 🏃, Walking 🚶, Yoga 🧘, Pilates 🥋, Gym 🏋️, and Other activities.
*   **Month 3+ Gym Program Guide**: Full interactive guide detailing Month 3+ Plans A, B, and C (warmups, exercises, sets, reps, rest times, notes, and cardio finishers).
*   **Sport Analytics & Charts**: Reactive Daily, Weekly, and Monthly stacked bar charts for duration and burned calories across all sports.
*   **Session Scheduling & One-Tap Completion**: Plan upcoming gym or sport sessions for target dates, with 1-tap "Done" completion directly from the tracker dashboard.
*   **Body Metrics Log**: Track weight, waist, chest, hip, bicep, and thigh dimensions. Supports goal-setting, metric directions (`gain` or `lose`), and progress state photo uploads. Tap any past log entry to edit its values or photos.
*   **Selectable Trend Chart**: Switch the Log tab's chart between Weight, Waist, Chest, Hip, Bicep, or Thigh to see progress on any tracked measurement, not just weight.

### 🧘 8. Wellbeing & Mindfulness
*   **Self-Care Catalog**: Choose wellbeing actions (reading, meditation, spa, stretching) and log completions.
*   **Mood Tracker**: Connect mood logs with daily logs to analyze patterns.

### 🩸 9. Period Tracker & Cycle Integration
*   **Cycle Predictions**: Track period dates, fertile windows, and ovulation days.
*   **Calendar & Day Detail Integration**: Dedicated `Period` top filter chip on the main calendar and a Cycle & Period section in `DayDetailScreen` with 1-tap "Started Today" logging.
*   **Late Markers & Analytics**: Flags late periods dynamically and presents visual cycle history graphs. calendar using dedicated rose styling.

### ⏱️ 10. Work Time Tracker
*   **Focus Contexts**: Organize work sessions by contexts or categories.
*   **Live Work Timer**: Track work durations with a stopwatch. Logs total hours and minutes to review productivity.

### 📱 11. Social Media tracker
*   **Account Profiles**: Track multiple social profiles.
*   **Social Activity Logs**: Schedule and record posts or story logs, and track follower growth metrics.

### 🏆 12. Achievements & Badges
*   **22 Unique Badges**: Awarded for streaks (habits), gym sessions, task completion milestones, work hours, self-care records, and job applications.
*   **Linear Fill Bars**: Grid items display visual completion progress bars (e.g., 5/10 workouts is 50% filled).
*   **Shareable Achievements**: Click any unlocked badge to open a stylized card and export it to share with friends.

### 🎨 13. Personalization
*   **Theme Mode**: Switch between Light, Dark, or System Default appearance from the More screen.
*   **App Font**: Restyle the entire app's typeface from More > App Settings — choose between Classic (Fraunces/Nunito Sans), Comic, Times Classic, Mono, and Fredoka, each fully bundled offline.

---

## 🛠️ Technical Stack & Architecture

*   **Framework**: [Flutter](https://flutter.dev) (Dart)
*   **State Management**: [Riverpod](https://riverpod.dev) (Dynamic family providers and state control)
*   **Local Database**: [Drift](https://drift.simonbinder.eu) (SQLite wrapper offering type-safe, reactive stream queries)
*   **Database Schema**: Designed with structured SQLite schemas defined in Dart:
    *   [core_day_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/core_day_tables.dart) (Tags, DayTags, Events, Trips, Reminders)
    *   [list_engine_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/list_engine_tables.dart) (Collections, Items, Subtasks, ChoreCompletions)
    *   [finance_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/finance_tables.dart) (Transactions, RecurringTransactions, Debts)
    *   [meals_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/meals_tables.dart) (Ingredients, Recipes, MealSlots)
    *   [fitness_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/fitness_tables.dart) (Workouts, GymSessions, Metrics)
    *   [wellbeing_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/wellbeing_tables.dart) (Actions, Logs)
    *   [period_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/period_tables.dart) (Period logs)
    *   [work_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/work_tables.dart) (Contexts, Time logs)
    *   [social_tables.dart](file:///M:/Nili-Personal-Planner/lib/core/db/tables/social_tables.dart) (Accounts, Social logs)
*   **Cross-Platform Images**: [image_service.dart](file:///M:/Nili-Personal-Planner/lib/core/services/image_service.dart) stores picked photos as local files on native platforms and as inline base64 data on web (no writable filesystem there), behind shared `hasDisplayableImage`/`imageProviderFor` helpers used across the app.
*   **Offline Google Fonts**: All app fonts (including the 5 selectable App Font options) are bundled locally under `assets/google_fonts/` — `GoogleFonts.config.allowRuntimeFetching` is disabled, so no font is ever fetched over the network.

---

## 📂 Directory Structure

```text
lib/
├── core/
│   ├── db/                 # Drift Database definitions, migrations & tables
│   ├── design/             # Color tokens, widgets, cards, and styling guides
│   ├── router/             # App routing and navigation declarations
│   └── services/           # Global notifications, backup and file service engines
└── features/
    ├── badges/             # Achievements, calculations, and badges screen
    ├── calendar/           # Main Planner calendar, event sheets, and day details
    ├── finance/            # Transactions list, recurring sync, debts, and forecast logic
    ├── fitness/            # Body metrics tracking, photo uploads, and goal sheets
    ├── habits/             # Habits database repositories and logs
    ├── lists/              # Shopping lists, templates, and travel packing collections
    ├── more/               # Backups, seeding, and settings
    ├── period/             # Period calculations, service, cycle graphs, and logs
    ├── reminders/          # Deadline triggers and task notifications
    ├── today/              # Dashboard widgets, skincare/hydration checklist, and 7-day projection
    ├── track/              # Hub for tracker features (Period, Gym, Wellbeing, Meals, Work Time)
    └── trips/              # Travel planners, budgets, and smart forecasts
```

---

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK (Stable channel)
*   Dart SDK

### 1. Installation

Clone the repository and fetch dependencies:

```bash
git clone https://github.com/niloufarmj/Nili-Personal-Planner.git
cd Nili-Personal-Planner
flutter pub get
```

### 2. Code Generation

Generate database code and Riverpod files:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run the App

Launch the planner on your simulator, emulator, or connected physical device:

```bash
flutter run
```

### 4. Running the Tests

Execute the comprehensive unit and widget test suite (285+ tests):

```bash
flutter test
```

---

## 🔒 Backup & Privacy

*   **100% Private**: Your data never leaves your device. All calculations, predictions, pictures, and records are stored locally in the SQLite container.
*   **Backup & Restore**: Easily export your database configuration and metrics as a ZIP file on the *Settings & More* screen, or load seed/mock data during local development.
