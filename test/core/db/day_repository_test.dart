import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';

void main() {
  late DayRepository repo;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DayRepository(db);
  });
  tearDown(() => db.close());

  // ── Seed ────────────────────────────────────────────────────────

  test('seedDefaultTagsIfNeeded inserts 6 default tags once', () async {
    await repo.seedDefaultTagsIfNeeded();
    final tags = await repo.getAllTags();
    expect(tags.length, 6);
    expect(
      tags.map((t) => t.name),
      containsAll(['linz', 'salzburg', 'travel']),
    );
  });

  test('seedDefaultTagsIfNeeded is idempotent', () async {
    await repo.seedDefaultTagsIfNeeded();
    await repo.seedDefaultTagsIfNeeded();
    final tags = await repo.getAllTags();
    expect(tags.length, 6);
  });

  // ── setTag / removeTag ───────────────────────────────────────────

  test('setTag adds a tag to a date', () async {
    await repo.seedDefaultTagsIfNeeded();
    final all = await repo.getAllTags();
    final linz = all.firstWhere((t) => t.name == 'linz');

    await repo.setTag('2026-01-15', linz.id);
    final result = await repo.getTagsForDate('2026-01-15');
    expect(result.map((t) => t.name), contains('linz'));
  });

  test('setTag is idempotent — duplicate is safe', () async {
    await repo.seedDefaultTagsIfNeeded();
    final tag = (await repo.getAllTags()).first;
    await repo.setTag('2026-01-15', tag.id);
    await repo.setTag('2026-01-15', tag.id); // second call must not throw
    final result = await repo.getTagsForDate('2026-01-15');
    expect(result.where((t) => t.id == tag.id).length, 1);
  });

  test('removeTag removes the tag from a date', () async {
    await repo.seedDefaultTagsIfNeeded();
    final tag = (await repo.getAllTags()).firstWhere((t) => t.name == 'gym');
    await repo.setTag('2026-01-15', tag.id);
    await repo.removeTag('2026-01-15', tag.id);
    final result = await repo.getTagsForDate('2026-01-15');
    expect(result.where((t) => t.id == tag.id), isEmpty);
  });

  test('source field is persisted correctly', () async {
    await repo.seedDefaultTagsIfNeeded();
    final tag = (await repo.getAllTags()).firstWhere((t) => t.name == 'travel');
    await repo.setTag('2026-01-15', tag.id, source: 'trip');
    final rows = await db.select(db.dayTags).get();
    expect(rows.first.source, 'trip');
  });

  // ── watchTagsForRange ─────────────────────────────────────────────

  test('watchTagsForRange emits updates when tags change', () async {
    await repo.seedDefaultTagsIfNeeded();
    final tag = (await repo.getAllTags()).firstWhere((t) => t.name == 'linz');
    final start = DateTime(2026, 1, 10);
    final end = DateTime(2026, 1, 20);

    final stream = repo.watchTagsForRange(start, end);

    // Listen and collect the first two emissions
    final emissions = <Map<String, List<dynamic>>>[];
    final sub = stream.listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await repo.setTag('2026-01-15', tag.id);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await sub.cancel();

    expect(emissions.length, greaterThanOrEqualTo(2));
    expect(emissions.last.containsKey('2026-01-15'), isTrue);
  });

  // ── setTagByNameForRange ─────────────────────────────────────────

  test('setTagByNameForRange writes tags for every day in range', () async {
    await repo.seedDefaultTagsIfNeeded();
    await repo.setTagByNameForRange(
      'travel',
      DateTime(2026, 1, 10),
      DateTime(2026, 1, 12),
      source: 'trip',
    );
    for (final date in ['2026-01-10', '2026-01-11', '2026-01-12']) {
      final tags = await repo.getTagsForDate(date);
      expect(tags.map((t) => t.name), contains('travel'), reason: 'date=$date');
    }
  });

  // ── createTag / updateTag ────────────────────────────────────────

  test('createTag and updateTag work correctly', () async {
    final id = await repo.createTag(
      name: 'custom',
      color: '#FF0000',
      kind: 'activity',
    );
    expect(id, isPositive);
    final tag = await repo.getTag(id);
    expect(tag.name, 'custom');

    final updated = tag.copyWith(name: 'renamed');
    await repo.updateTag(updated);
    final after = await repo.getTag(id);
    expect(after.name, 'renamed');
  });
}
