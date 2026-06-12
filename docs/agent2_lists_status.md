# Agent 2 — Lists Engine: Status

Branch: `feat/health` (all lists work committed here)

## Done

| Step | Description | Commit |
|------|-------------|--------|
| 1 | `CollectionRepository` + `ItemRepository` with 19 unit tests | `a55c946` |
| 2 | `TemplateRegistry` — 9 templates (simple, chore, shopping, upgrade, task, job, growth, media, probable) with 15 unit tests | `101140a` |
| 3 | `ListsScreen` — live grid grouped by template, new-list two-step sheet, `CollectionCounts` widget, 4 widget tests | `f1a9c69` |
| 4 | `CollectionScreen` — item list with swipe actions, `ItemEditSheet` (template-driven, no per-template code), `SubtaskList`, collection route wired in router, 6 widget tests | `feda07f` |
| 5 (partial) | `ChoreCompletions` table + schema migration v2 (`schemaVersion` bumped from 1→2) + `ChoreService` skeleton | this commit |

## Files Owned (lib/features/lists/)

```
lib/features/lists/
  lists_screen.dart               ✅ done
  screens/
    collection_screen.dart        ✅ done
  widgets/
    collection_counts.dart        ✅ done
    item_edit_sheet.dart          ✅ done
    subtask_list.dart             ✅ done
  repositories/
    collection_repository.dart    ✅ done
    item_repository.dart          ✅ done
  templates/
    template_registry.dart        ✅ done
  services/
    chore_service.dart            ⚠️ written, tests failing on RRULE advancement
lib/core/db/tables/
  chore_tables.dart               ✅ done (ChoreCompletions table)
lib/core/db/database.dart         ✅ schemaVersion=2, migration added
```

## Missing / Incomplete

### Step 5 — Chore recurrence (PARTIALLY DONE)
- `ChoreService.completeChore()` — written but **tests failing**
  - `isOverdue()` — works correctly (4 tests pass)
  - `completeChore()` + RRULE advancement — daily works, weekly/monthly fail
  - **Root cause**: `_nextOccurrence` uses `.skip(1).first` on rrule instances, should work but needs re-verification after last edit
  - Tests in `test/features/lists/services/chore_service_test.dart` — **not yet confirmed green**

### Step 6 — Calendar integration
- Verify `items.due_date` dots appear on calendar via aggregator (aggregator may already support it)
- Add due-items section to the day detail sheet
- Register "Tasks" filter chip if not present
- Tests: aggregator seeded with due items; day sheet lists them

### Step 7 — First-launch seed collections
- Seed on first launch (idempotent):
  - Chores (chore), Shopping (shopping), Tech Wishlist (shopping), Life Upgrades (upgrade)
  - University (task), Personal Projects (task), Personal Growth (growth), Hobbies (media)
  - Probable Plans (probable)
  - Job Hunt (job) with children: Germany, Netherlands, Spain, Australia
- No content items seeded
- Tests: idempotent seeding

### Final gate
- `dart format .` — clean
- `flutter analyze` — zero issues in lists/ files (other agents have pre-existing issues in conflict_engine_test and shopping_generator_test)
- `flutter test` — lists tests all green; pre-existing failures in other agents' widget tests (TransactionTile, GymScreen, nav_shell)
- Merge to main

## Known Pre-existing Issues (Other Agents, Not Lists)
- `test/core/conflicts/conflict_engine_test.dart:155,164` — type errors
- `test/features/meals/shopping_generator_test.dart:265` — undefined name 'drift'
- `test/features/finance/widget_test.dart` — pending drift timer (TransactionTile test)
- `test/features/gym/gym_widget_test.dart` — pending drift timer (GymScreen test)
- `test/features/nav_shell_test.dart` — pending drift timer + "Work Time" text missing
