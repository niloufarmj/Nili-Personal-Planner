# Personal Planner App — Design Documentation v1.0

**Working name:** (TBD)
**Owner:** Nili
**Type:** Fully local mobile app — no server, no external database, no accounts
**Status:** Design phase. All data placeholders empty; content filled later.

---

## 1. Product Summary

A single personal life-management app that replaces scattered notes, Notion pages, and mental load. The core differentiator from Notion/Todoist: **pages are connected through a shared day/calendar layer**, so travel plans affect gym plans, meal plans generate shopping lists, shopping lists feed the expense tracker, and everything appears on one filterable calendar.

### Design principles
1. **Hub-and-spoke, not page-to-page.** Every module reads/writes the central `days` + `events` layer. No module talks directly to another module.
2. **Propose, never auto-delete.** Conflicts (travel on a gym day) produce suggestions, not silent changes.
3. **One-tap logging.** Any recurring input (water, habit, gym done, expense) must be loggable in ≤2 taps from the Today screen.
4. **Generic list engine.** All simple list-pages are templates over one data model — not bespoke code.
5. **Planned vs. actual everywhere.** Estimates and reality live in the same tables, distinguished by status.

---

## 2. Tech Stack (recommended)

| Layer | Choice | Why |
|---|---|---|
| Framework | **Flutter** | Single codebase iOS+Android, strong calendar/chart packages, learnable fast coming from C#/Unity |
| Database | **SQLite via `drift`** | Typed schema, reactive queries (UI auto-updates when data changes), migrations |
| Notifications | `flutter_local_notifications` | Fully offline, supports scheduled + repeating |
| Charts | `fl_chart` | Fitness progress, expense breakdowns |
| Calendar UI | `table_calendar` (customizable) | Supports day decorations (color overlays, dots per category) |
| Images | App documents dir + `image_picker`, compressed on save | Progress photos, item images |
| Backup | Manual export/import of an encrypted `.zip` (DB + images) via system share sheet | Local-first survival of phone loss |
| Device calendar (optional, v2) | `device_calendar` read-only | See Google Calendar events without running a server |

Alternative: .NET MAUI (closer to C#) — viable, but Flutter's package ecosystem for calendars/charts is stronger. Decision point in Phase 0.

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    UI PAGES (~20)                    │
│  Expense · Meals · Gym · Travel · Jobs · Lists · …  │
└──────────────┬──────────────────────┬───────────────┘
               │ read/write           │ rendered by
┌──────────────▼──────────┐  ┌────────▼───────────────┐
│   GENERIC LIST ENGINE   │  │   CALENDAR AGGREGATOR  │
│ collections/items/      │  │ merges all date-bearing│
│ subtasks/custom fields  │  │ rows into one feed     │
└──────────────┬──────────┘  └────────▲───────────────┘
               │                      │
┌──────────────▼──────────────────────┴───────────────┐
│              CORE DAY LAYER (the hub)                │
│   days · day_tags · events · trips · reminders      │
└──────────────┬───────────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────────┐
│  DOMAIN MODULES: finance · meals · fitness · habits  │
│  work-time · wellbeing  (each reads day tags)        │
└───────────────────────────────────────────────────────┘
```

**Conflict engine:** a small rule set evaluated whenever day tags change. Example rules:
- `travel` tag added to a day with a planned `gym_session` → notification: "You planned Gym B on Jul 14 but you'll be traveling — move it?"
- `linz` tag on a day with a `salzburg`-only chore → flag.
Rules live in code (not DB) for v1; ~5–10 rules expected.

---

## 4. Database Schema

> Convention: all dates ISO-8601 strings (`YYYY-MM-DD`), timestamps in local time, money in integer cents (EUR), images stored as relative file paths. `meta` columns are JSON for template-specific fields.

### 4.1 Core day layer (the hub)

```sql
-- Tags define day types. Owner distinguishes user vs. partner overlays.
CREATE TABLE tags (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,            -- 'linz', 'salzburg', 'travel', 'gym', 'work', 'reza-day', ...
  color       TEXT NOT NULL,            -- hex; e.g. linz=#F5C518, salzburg=#7C5CBF, travel=#3EBF6F
  kind        TEXT NOT NULL,            -- 'location' | 'activity' | 'special' | 'partner'
  owner       TEXT NOT NULL DEFAULT 'me'  -- 'me' | 'partner'
);

-- A day exists implicitly; this table holds its tags (many-to-many).
CREATE TABLE day_tags (
  date        TEXT NOT NULL,
  tag_id      INTEGER NOT NULL REFERENCES tags(id),
  source      TEXT NOT NULL DEFAULT 'manual',  -- 'manual' | 'trip' | 'recurrence'
  PRIMARY KEY (date, tag_id)
);

-- Timed or all-day calendar entries (social events, appointments, partner exams).
CREATE TABLE events (
  id          INTEGER PRIMARY KEY,
  title       TEXT NOT NULL,
  date        TEXT NOT NULL,
  start_time  TEXT,                     -- NULL = all-day
  end_time    TEXT,
  location    TEXT,
  category    TEXT NOT NULL,            -- 'social' | 'appointment' | 'partner' | 'uni' | 'other'
  rrule       TEXT,                     -- iCal RRULE for weekly repeats; NULL = one-off
  notes       TEXT,
  owner       TEXT NOT NULL DEFAULT 'me'
);

-- Trips: probable or final. Final trips auto-write 'travel' day_tags for their range.
CREATE TABLE trips (
  id          INTEGER PRIMARY KEY,
  title       TEXT NOT NULL,
  status      TEXT NOT NULL,            -- 'probable' | 'final' | 'done' | 'cancelled'
  start_date  TEXT,
  end_date    TEXT,
  location    TEXT,
  description TEXT,
  links       TEXT,                     -- JSON array of URLs
  budget_cents INTEGER,                 -- mirrors a planned transaction
  packing_collection_id INTEGER,        -- FK → collections (packing list)
  meta        TEXT                      -- JSON: images, etc.
);

-- Standalone reminders with a validity window and priority (e.g. visa office visit).
CREATE TABLE reminders (
  id          INTEGER PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT,
  window_start TEXT NOT NULL,
  window_end  TEXT,
  priority    INTEGER NOT NULL DEFAULT 2,  -- 1 high · 2 normal · 3 low
  notify_rule TEXT,                     -- JSON: when to fire local notifications
  status      TEXT NOT NULL DEFAULT 'open' -- 'open' | 'done' | 'dismissed'
);
```

### 4.2 Generic list engine (powers ~12 pages)

```sql
CREATE TABLE collections (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,            -- 'Iran shopping', 'Germany companies', 'Chores', ...
  template    TEXT NOT NULL,            -- see template registry below
  parent_id   INTEGER REFERENCES collections(id),  -- e.g. country lists under Job Hunt
  icon        TEXT,
  sort_order  INTEGER,
  archived    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE items (
  id          INTEGER PRIMARY KEY,
  collection_id INTEGER NOT NULL REFERENCES collections(id),
  title       TEXT NOT NULL,
  description TEXT,
  status      TEXT NOT NULL DEFAULT 'open',  -- template-defined vocab
  priority    INTEGER,                  -- 1 high · 2 normal · 3 low
  due_date    TEXT,
  done_date   TEXT,                     -- set when ticked
  planned_cost_cents INTEGER,           -- shopping/upgrades
  recurrence  TEXT,                     -- RRULE for chores ('FREQ=WEEKLY;BYDAY=SA')
  image_before TEXT,                    -- life-upgrade plan image
  image_after  TEXT,                    -- life-upgrade done image
  meta        TEXT                      -- JSON: template-specific fields
);

CREATE TABLE subtasks (
  id          INTEGER PRIMARY KEY,
  item_id     INTEGER NOT NULL REFERENCES items(id),
  title       TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open',
  sort_order  INTEGER
);
```

**Template registry** (defines which fields/status values the UI shows — code, not DB):

| Template | Used by pages | Extra fields in `meta` | Statuses |
|---|---|---|---|
| `simple` | Custom lists, packing lists | — | open/done |
| `chore` | Chores | room | open/done (recurring auto-reset) |
| `shopping` | Shopping list, tech wishlist | shop_url | wanted/bought |
| `upgrade` | Life upgrade plans | — | planned/done (+before/after images) |
| `task` | Uni tasks, personal projects, work tasks | course/context | todo/in-progress/done/blocked |
| `job` | Job hunting (one collection per country) | company, role, link, email, contact | researching/applied/interview/rejected/offer |
| `growth` | Personal growth goals | resource_link, target_hours, result | planned/active/done |
| `media` | Hobbies: books/movies/series/games | kind, total_time_spent | backlog/active/done |
| `probable` | Probable plans page | promote_target | undecided/promoted/dropped |

**Page → engine mapping:** Chores, Shopping, Tech Wishlist, Life Upgrades, Uni Tasks, Personal Projects, Job Hunt, Personal Growth, Hobbies, Probable Plans, Packing Lists, and any user-created list = **zero new tables each**.

### 4.3 Finance

```sql
CREATE TABLE transactions (
  id          INTEGER PRIMARY KEY,
  date        TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,        -- positive
  direction   TEXT NOT NULL,            -- 'in' | 'out'
  status      TEXT NOT NULL,            -- 'actual' | 'planned'   ← estimates live here too
  category    TEXT NOT NULL,            -- 'rent','food','transport','travel','shopping','income',...
  note        TEXT,
  item_id     INTEGER REFERENCES items(id),   -- link: bought shopping-list item
  trip_id     INTEGER REFERENCES trips(id)    -- link: trip budget
);

-- Subscriptions, rent, salary — expanded into projected months for forecasts.
CREATE TABLE recurring_transactions (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,            -- 'Rent', 'Klimaticket', 'Claude', 'SIM', 'Gym', 'Salary'
  amount_cents INTEGER NOT NULL,
  direction   TEXT NOT NULL,
  day_of_month INTEGER NOT NULL,
  start_month TEXT NOT NULL,            -- 'YYYY-MM'
  end_month   TEXT,                     -- NULL = ongoing
  category    TEXT NOT NULL,
  active      INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE debts (
  id          INTEGER PRIMARY KEY,
  person      TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  direction   TEXT NOT NULL,            -- 'i_owe' | 'owes_me'
  note        TEXT,
  settled     INTEGER NOT NULL DEFAULT 0
);
```

**Monthly forecast** = recurring expansion + planned transactions + actuals to date → "estimated end-of-month balance" card.

### 4.4 Meals & shopping generation

```sql
CREATE TABLE ingredients (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,
  category    TEXT,                     -- 'produce','dairy','pantry',... (groups shopping list)
  kcal_per_100g REAL,                   -- nullable; v1 may skip macros
  protein_per_100g REAL
);

CREATE TABLE recipes (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,
  meal_slot   TEXT NOT NULL,            -- 'breakfast' | 'lunch' | 'dinner' | 'any'
  prep_minutes INTEGER,
  tags        TEXT NOT NULL,            -- JSON: ['quick','prep-ahead','high-protein','reza-shared','needs-oven']
  instructions TEXT,
  image       TEXT
);

CREATE TABLE recipe_ingredients (
  recipe_id   INTEGER NOT NULL REFERENCES recipes(id),
  ingredient_id INTEGER NOT NULL REFERENCES ingredients(id),
  amount      REAL NOT NULL,
  unit        TEXT NOT NULL,            -- 'g','ml','pcs','tbsp'
  PRIMARY KEY (recipe_id, ingredient_id)
);

CREATE TABLE meal_slots (
  date        TEXT NOT NULL,
  slot        TEXT NOT NULL,            -- 'breakfast' | 'lunch' | 'dinner' | 'post-gym-shake'
  recipe_id   INTEGER REFERENCES recipes(id),
  status      TEXT NOT NULL,            -- 'suggested' | 'accepted' | 'eaten' | 'skipped'
  PRIMARY KEY (date, slot)
);
```

**Suggestion algorithm (no AI — pure filtering):**
1. Sunday reminder: "Confirm next week's day tags" (linz/salzburg/gym/work/reza per day).
2. For each of 21 slots, derive constraints from day tags:
   - gym day → dinner must include `high-protein`; add `post-gym-shake` slot
   - work day → lunch must be `prep-ahead` or `quick`
   - reza/linz day → prefer `reza-shared`
   - salzburg-alone day → any
3. Filter recipe pool per slot by constraints; exclude recipes used in the last 3 days; pick randomly.
4. Show the week grid; user swaps any cell from the valid pool; accepts.
5. **Generate shopping list:** sum `recipe_ingredients` across accepted slots, group by ingredient category, write to a "Groceries — week of X" collection. Buying items can log expenses (`item_id` link).

Complexity: ~40 recipes × 21 slots — instant on-device. v1 ships **tags only**; macros/calories are a v2 column-fill, no schema change needed.

### 4.5 Fitness & habits

```sql
CREATE TABLE workout_plans (              -- her existing A/B/C plans, stored as content
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, content TEXT NOT NULL  -- markdown
);

CREATE TABLE gym_sessions (
  id          INTEGER PRIMARY KEY,
  date        TEXT NOT NULL,
  plan_id     INTEGER REFERENCES workout_plans(id),
  status      TEXT NOT NULL,            -- 'planned' | 'done' | 'missed'
  start_time  TEXT,
  duration_min INTEGER,
  notes       TEXT
);
-- Rule: 'planned' sessions whose date passes without 'done' auto-mark 'missed' (kept for stats, hidden from upcoming).

CREATE TABLE measurements (
  id          INTEGER PRIMARY KEY,
  date        TEXT NOT NULL,
  weight_kg   REAL,
  fields      TEXT,                     -- JSON: {waist_cm, hip_cm, ...} — user-definable
  photos      TEXT                      -- JSON array of image paths
);

CREATE TABLE fitness_goals (
  id INTEGER PRIMARY KEY, metric TEXT NOT NULL, target REAL NOT NULL,
  deadline TEXT, achieved_date TEXT
);

CREATE TABLE habits (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,            -- 'Water', 'Skincare AM', 'Skincare PM', 'Teeth', 'Reading'
  target_per_day INTEGER NOT NULL DEFAULT 1,   -- water = 8
  reminder_times TEXT,                  -- JSON: ['09:00','13:00','17:00','21:00'] (batched, not hourly)
  active      INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE habit_logs (
  habit_id    INTEGER NOT NULL REFERENCES habits(id),
  date        TEXT NOT NULL,
  count       INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (habit_id, date)
);
```

### 4.6 Wellbeing ("Feeling Better" page)

```sql
CREATE TABLE wellbeing_actions (          -- 'meditation', 'talk to a friend', 'listen to music' (+user-added)
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE wellbeing_logs (
  date        TEXT NOT NULL,
  action_id   INTEGER NOT NULL REFERENCES wellbeing_actions(id),
  PRIMARY KEY (date, action_id)
);
-- History view: calendar heat dots = "did something for myself that day".
```

### 4.7 Work time tracking

```sql
CREATE TABLE work_contexts (              -- 'FreshFX', 'Tutoring', 'Startup'
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, color TEXT
);
-- Work tasks themselves use the list engine (template 'task', meta.context_id set).

CREATE TABLE time_entries (
  id          INTEGER PRIMARY KEY,
  context_id  INTEGER NOT NULL REFERENCES work_contexts(id),
  item_id     INTEGER REFERENCES items(id),   -- optional: specific task
  date        TEXT NOT NULL,
  minutes     INTEGER NOT NULL,
  note        TEXT
);
-- Rollups: per day, per task, per context, per month. Powers the "saved overtime → travel days" counter.
```

### 4.8 Social media tracker

```sql
CREATE TABLE social_accounts (
  id INTEGER PRIMARY KEY, platform TEXT NOT NULL, goal TEXT
);
CREATE TABLE social_logs (
  id INTEGER PRIMARY KEY,
  account_id INTEGER NOT NULL REFERENCES social_accounts(id),
  date TEXT NOT NULL,
  minutes_spent INTEGER,
  activity TEXT,                        -- 'post' | 'story' | 'comment' | 'browse'
  note TEXT
);
```

---

## 5. Calendar System (the centerpiece)

### Main calendar
Month view aggregating **every date-bearing row** in the app:

| Source | Rendering |
|---|---|
| `day_tags` (location) | Full-cell color overlay: Linz yellow · Salzburg purple · Travel green |
| `day_tags` (activity) | Small icons in cell (dumbbell, briefcase) |
| `events` | Dots + agenda list below |
| `trips` (final) | Spanning bar across the range |
| `meal_slots` (accepted) | Dot; tap-through to day's menu |
| `gym_sessions` | Dot (outlined = planned, filled = done) |
| `items.due_date` | Dot, colored by collection |
| `reminders` | Banner during the window |
| Partner (`owner='partner'`) | Thin strip widget at top of each cell |

**Filter bar:** chips — All · Location · Gym · Meals · Work · Uni · Travel · Social · Tasks · Partner. Multi-select, persisted per user.

**Day detail sheet** (tap a day): tags editor, that day's events, meals, gym session, due items, habit progress — one place to see and edit a whole day.

### Per-page mini-calendars
Same calendar widget, pre-filtered to that page's source (one shared component):
- Gym page → sessions only (with travel-day greying from the conflict engine)
- Meal page → week grid view
- Travel page → trips + probable plans
- Work page → time-entry heat map
- Fitness page → measurement reminder dots

---

## 6. Pages & Navigation

**Bottom navigation (5 tabs):**

1. **Today** (home) — date + tags, today's meals, gym session, due items, habit tap-counters (water 🥤 ×8), quick-add button, active reminders.
2. **Calendar** — the main filterable calendar.
3. **Lists** — grid of all list-engine collections (Chores, Shopping, Uni, Jobs, Projects, Hobbies, Upgrades, Probable Plans, custom…). "+ New list" → pick template.
4. **Track** — Finance · Meals · Fitness · Gym · Habits · Feeling Better · Work Time · Social Media.
5. **More** — Travel Planner · Reminders · Partner Schedule settings · Personal Growth · Backup/Export · App settings.

**Full page inventory (all pages from the planning doc, mapped):**

| # | Page from doc | Implementation |
|---|---|---|
| 1 | Expense tracker (+estimates) | Finance module (4.3) |
| 2 | Feeling Better | Wellbeing (4.6) |
| 3 | User-created lists (e.g. Iran shopping) | List engine, `simple` |
| 4 | Probable plans/events | List engine, `probable` (promote → trip/event) |
| 5 | Chores (daily/weekly/monthly) | List engine, `chore` + RRULE |
| 6 | Shopping list w/ priority+budget | List engine, `shopping` → finance link |
| 7 | Travel planner (calendar, packing, links, images, history) | Trips (4.1) + packing collections |
| 8 | Life upgrade plans (before/after images) | List engine, `upgrade` |
| 9 | University tasks (subtasks, deadlines) | List engine, `task` |
| 10 | Work todos + time tracking | List engine `task` + time_entries (4.7) |
| 11 | Reminders (date window, priority) | Reminders (4.1) |
| 12 | Job hunting per country | Collections per country, `job` template |
| 13 | Personal projects | List engine, `task` |
| 14 | Personal growth | List engine, `growth` |
| 15 | Social media tracker | 4.8 |
| 16 | Partner schedule | Partner tags/events + calendar strip |
| 17 | Social events (repeating) | Events + RRULE |
| 18 | Hobbies (books/movies/time) | List engine, `media` |
| 19 | Fitness tracker (photos, charts, goals) | Measurements + goals (4.5) |
| 20 | Gym plan + sessions | Workout plans + sessions (4.5) |
| 21 | Meal planner + suggestions | Meals (4.4) |
| 22 | Water + daily habits | Habits (4.5) |

---

## 7. UX & Friendliness Requirements

- **Quick-add everywhere:** floating + button on Today/Calendar → "Expense · Event · Task · Trip · Note" in one tap each.
- **Habit logging = tap counters** on Today, no forms.
- **Batched notifications:** habits fire at 3–4 fixed check-in times, not hourly. Weekly: Sunday "plan next week" (tags + meals), measurement reminder; Monthly: photo + measurement reminder, finance review.
- **Conflict suggestions** appear as dismissible cards on Today, never modal interruptions.
- **Empty states** explain each page in one sentence with a sample item (placeholder data — to be filled later per your note).
- **Color language:** Linz #F5C518 · Salzburg #7C5CBF · Travel #3EBF6F (consistent across calendar, cards, charts). Full palette/typography decided in Phase 0 design pass.
- **Bilingual-friendly:** strings externalized from day one (EN first; FA/DE possible later).
- Dark mode from Phase 0 (cheap if done early, painful later).

---

## 8. Backup & Data Safety

- Export: zip of `app.db` + `/images`, optionally encrypted with a passphrase → system share sheet (save to Drive/anywhere). Import restores fully.
- Reminder nudge: "Last backup 30+ days ago."
- DB migrations versioned via drift from the first release — schema will evolve.

---

## 9. Build Plan

Estimates assume part-time solo work (~8–10 h/week) alongside thesis/job.

| Phase | Scope | Est. |
|---|---|---|
| **0 — Foundation** | Stack decision, project setup, drift schema for core tables, navigation shell, design system (colors/typography/components), dark mode | 1–2 wks |
| **1 — Core hub** | Days + tags + tag editor, events (+RRULE), main calendar with overlays/filters, day detail sheet, Today screen skeleton | 2–3 wks |
| **2 — List engine** | Collections/items/subtasks, all 9 templates, recurring chores, images on items, Lists tab | 2–3 wks |
| **3 — Finance** | Transactions, recurring, planned-vs-actual, debts, monthly forecast card, charts, shopping-list → expense link | 2 wks |
| **4 — Trips & reminders** | Trips (probable/final), auto day-tags, packing lists, reminders w/ notifications, partner schedule + calendar strip, conflict engine v1 (travel↔gym) | 2 wks |
| **5 — Fitness & habits** | Gym plans/sessions, auto-missed rule, measurements + photos + charts + goals, habits with tap counters + batched notifications, Feeling Better page | 2 wks |
| **6 — Meals** | Ingredients/recipes/slots, weekly tag-confirm flow, suggestion algorithm, week grid w/ swap, shopping-list generation | 2–3 wks |
| **7 — Work & career** | Work contexts, time entries + rollups, overtime→travel-days counter, job-hunt collections, social media tracker | 1–2 wks |
| **8 — Polish & safety** | Backup/export/import, empty states, performance pass, icon/splash, on-device testing both platforms | 1–2 wks |

**Total: ~13–19 weeks part-time.** Each phase ends with a usable build — **start living in the app from Phase 1** (calendar + tags alone already replace mental load) so real usage steers later phases.

### Risk register
| Risk | Mitigation |
|---|---|
| Scope creep mid-build | Schema is final for v1; new ideas go to a "v2" list (in the app, fittingly) |
| Logging fatigue | Every recurring input audited for ≤2 taps; cut anything that fails |
| Recipe data entry tedium | Tags-only v1; macros later; enter recipes gradually (5/week) |
| Notification limits (Android Doze) | Batched fixed-time notifications; no exact hourly alarms |
| Phone loss | Backup from Phase 8 — do not postpone past v1 |

---

## 10. Deferred to v2
- Macros/calorie balancing in meal suggestions (columns already exist)
- Pantry tracking ("subtract what I have")
- Read-only device-calendar (Google Calendar) overlay
- FA/DE localization
- Home-screen widgets (today's tags + water counter)
- Stats dashboard (cross-module: "spend vs. gym attendance vs. mood")
