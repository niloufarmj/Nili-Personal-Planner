# Nili Personal Planner 🚀

A comprehensive, beautifully designed, and offline-first personal organizer built with Flutter. Nili Personal Planner combines daily habit tracking, list management, travel planning, fitness logs, period predictions, achievements gamification, and intelligent finance forecasting into a unified dashboard.

---

## 🌟 Key Features

### 📅 Today's Dashboard & Next 7 Days
*   **Daily Hydration & Skincare**: Track water glasses, skincare routines, vitamin schedules, and dental habits.
*   **Daily Focus & Priorities**: Mark checklist tasks and priorities with gamified feedback.
*   **7-Day Horizon Planner**: Dedicated view displaying upcoming deadlines and plans for the next week.

### 💰 Intelligent Finance Tracking & Forecasting
*   **Income & Expense Log**: Filterable transactions list with categorization.
*   **Auto-Syncing Subscriptions & Salary**: Set your monthly salary day (e.g., 1250 on the 27th) and subscriptions (Klimaticket, internet, Claude, etc.). The app automatically logs passed transactions when you load the dashboard.
*   **Smart Balance Forecaster**: When editing travel plans or shopping items, Nili forecasts your estimated left balance on the target date. The forecast combines:
    *   Current actual balance.
    *   Active recurring salaries/subscriptions.
    *   Planned future expenses.
    *   A pro-rated mean of your historical variable spending (groceries, shopping, health, etc.).
*   **Debts Center**: Track money you owe (`i_owe`) or are owed (`owes_me`). Supports editing, and automatically prompts you to log matching payments or payoffs in your finances when a debt's amount is changed.

### 🩸 Period Tracker
*   **Cycle Prediction**: Automatically predicts your next period dates, signals when it is near, and marks it late if past due.
*   **Ovulation Detection**: Predicts fertile days and ovulation dates based on historical logs.
*   **Visual Cycle Diagrams**: Renders interactive graphs of your cycle history.
*   **Calendar Sync**: Highlights period days directly in the main planner calendar using dedicated rose themes.

### 🏋️ Trackers & Logs
*   **Fitness Center**: Log weight, waist size, chest, hips, biceps, and thighs. Support for goal tracking and state photo uploads.
*   **Wellbeing & Self-Care**: Track meditation, reading, and wellness sessions.
*   **Meal Planner**: Plan weekly menus and log completed/eaten meals.
*   **Work Time Tracker**: Log working hours with a live timer to review total working productivity.
*   **Job Hunt Tracker**: Track applications, companies applied to, interview statuses, and application timelines.

### 🏆 Gamification & Badges
*   **22 Unique Achievements**: Badges covering fitness, work, self-care, habits, list completions, and job applications.
*   **Linear Fill Bars**: Each badge card shows a real-time progress bar indicating how close you are to unlocking it (e.g., 5/10 days is 50% filled).
*   **Shareable Achievements**: Click any unlocked badge to open a stylized card and export it to other apps or share it with friends.

---

## 🛠️ Technical Stack & Architecture

Nili Personal Planner is built using a clean, modern, and modular architectural pattern:

*   **Framework**: [Flutter](https://flutter.dev) (Dart)
*   **State Management**: [Riverpod](https://riverpod.dev) (Decoupled, compile-safe, and family providers)
*   **Local Database**: [Drift](https://drift.simonbinder.eu) (SQLite wrapper for Dart offering fast, type-safe, reactive stream queries)
*   **UI/UX**: Custom design system utilizing curated theme palettes, glassmorphism, elegant dark modes, and micro-animations.
*   **Local Notifications**: Scheduled daily batch alarms for habits and reminders.

### 📂 Directory Structure

```text
lib/
├── core/
│   ├── db/                 # Drift Database definitions, migrations & tables
│   ├── design/             # Color tokens, widgets, cards, and styling guides
│   ├── router/             # App routing and navigation declarations
│   └── services/           # Global notifications, backup and file service engines
└── features/
    ├── badges/             # Gamification models, service, and Achievements screen
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

*   **100% Private**: Your data never leaves your device. All calculations, predictions, pictures, and records are stored locally in the sqlite container.
*   **Backup & Restore**: Easily export your database configuration and metrics as a ZIP file on the *Settings & More* screen, or load seed/mock data during local development.
