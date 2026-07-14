# Nili Personal Planner 🚀

A comprehensive, beautifully designed, and offline-first personal organizer built with Flutter. Nili Personal Planner integrates day-to-day agendas, modular tracking engines, recipe books, fitness records, social media logs, period forecasting, gamified achievements, and intelligent finance forecasting into a unified dashboard.

---

## 🌟 Core Modules & Features

### 📅 1. Planner & Calendar
*   **Day Tagging**: Personalize daily logs with custom tags, mood emojis, energy levels, and statuses.
*   **Daily Agenda**: Create and schedule events with start/end times, category labels, descriptions, and custom alerts.
*   **Reminders Engine**: Manage custom notifications, recurring triggers, and alarm configurations.

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
*   **Subtasks & Checklists**: Break down list items into smaller multi-step subtasks.
*   **Periodic Chores**: Log periodic tasks (cleaning, laundry, plant watering) with history logs.
*   **Shopping Actual Cost Prompts**: Mark items as "bought" to prompt for actual costs and automatically record them as shopping transactions.

### ✈️ 5. Smart Travel Planner
*   **Destinations & Budgets**: Detail travel periods, destination descriptions, and budgets.
*   **Packing Lists**: Generate packing lists linked directly to your travel dates.
*   **Forecast Integration**: Live forecaster computes whether your trip budget is sustainable based on future financial schedules.

### 🥩 6. Meal Planner & Recipe Book
*   **Ingredient Bank**: Manage pantry supplies, measuring units, and quantities.
*   **Recipe Creator**: Detail recipes, prep times, cooking steps, and list ingredient mappings.
*   **Weekly Meal Slot Board**: Plan weekly breakfasts, lunches, dinners, and snacks. Mark slots as `'planned'` or `'eaten'`.

### 🏋️ 7. Fitness, Gym & Weight Metrics
*   **Workout Routine Creator**: Design workout plans with custom exercises, sets, reps, and target weights.
*   **Gym Session Tracker**: Check in to gym sessions and log completed exercises in real-time.
*   **Body Metrics Log**: Track weight, waist, chest, hip, bicep, and thigh dimensions. Supports goal-setting, metric directions (`gain` or `lose`), and progress state photo uploads.

### 🧘 8. Wellbeing & Mindfulness
*   **Self-Care Catalog**: Choose wellbeing actions (reading, meditation, spa, stretching) and log completions.
*   **Mood Tracker**: Connect mood logs with daily logs to analyze patterns.

### 🩸 9. Period Tracker
*   **Cycle Predictions**: Track period dates, fertile windows, and ovulation days.
*   **Late Markers**: Flags late periods dynamically.
*   **Cycle Diagrams**: Visual cycle history graphs.
*   **Calendar Sync**: Highlights period days on the main planner calendar using dedicated rose styling.

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
