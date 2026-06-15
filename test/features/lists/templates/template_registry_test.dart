import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/features/lists/templates/template_registry.dart';

void main() {
  group('TemplateRegistry', () {
    test('all 9 templates are registered', () {
      expect(TemplateRegistry.all.length, 9);
    });

    test('every template has at least 2 statuses', () {
      for (final t in TemplateRegistry.all) {
        expect(
          t.statuses.length,
          greaterThanOrEqualTo(2),
          reason: '${t.id} needs at least 2 statuses',
        );
      }
    });

    test('every template has exactly one doneStatus entry in statuses', () {
      for (final t in TemplateRegistry.all) {
        final doneEntries = t.statuses.where((s) => s.isDone).toList();
        expect(
          doneEntries.length,
          1,
          reason: '${t.id} must have exactly one isDone=true status',
        );
        expect(
          doneEntries.first.value,
          t.doneStatus,
          reason: '${t.id} doneStatus must match the isDone status value',
        );
      }
    });

    test('every template openStatus appears in its statuses list', () {
      for (final t in TemplateRegistry.all) {
        expect(
          t.statuses.any((s) => s.value == t.openStatus),
          isTrue,
          reason: '${t.id} openStatus "${t.openStatus}" not in statuses',
        );
      }
    });

    test('select fields have non-empty options list', () {
      for (final t in TemplateRegistry.all) {
        for (final f in t.metaFields) {
          if (f.type == MetaFieldType.select) {
            expect(
              f.options?.isNotEmpty,
              isTrue,
              reason: '${t.id}.${f.key} is select but has no options',
            );
          }
        }
      }
    });

    test('get returns simple template as fallback for unknown id', () {
      final t = TemplateRegistry.get('nonexistent_template_xyz');
      expect(t.id, 'simple');
    });

    // ── Per-template spot checks ─────────────────────────────────────

    test('chore template has recurrence field visible', () {
      final t = TemplateRegistry.get('chore');
      expect(t.fields.recurrence, isTrue);
    });

    test(
      'shopping template has plannedCost visible and wanted/bought statuses',
      () {
        final t = TemplateRegistry.get('shopping');
        expect(t.fields.plannedCost, isTrue);
        expect(t.openStatus, 'wanted');
        expect(t.doneStatus, 'bought');
      },
    );

    test('upgrade template has image fields', () {
      final t = TemplateRegistry.get('upgrade');
      expect(t.fields.imageBefore, isTrue);
      expect(t.fields.imageAfter, isTrue);
    });

    test('task template has 4 statuses including blocked', () {
      final t = TemplateRegistry.get('task');
      expect(t.statuses.length, 4);
      expect(t.statuses.any((s) => s.value == 'blocked'), isTrue);
    });

    test('job template has 5 statuses including offer', () {
      final t = TemplateRegistry.get('job');
      expect(t.statuses.length, 5);
      expect(t.doneStatus, 'offer');
    });

    test('media template has kind select field', () {
      final t = TemplateRegistry.get('media');
      final kindField = t.metaFields.firstWhere((f) => f.key == 'kind');
      expect(kindField.type, MetaFieldType.select);
      expect(kindField.options, isNotEmpty);
    });

    test('probable template has promote_target meta field', () {
      final t = TemplateRegistry.get('probable');
      expect(t.metaFields.any((f) => f.key == 'promote_target'), isTrue);
    });

    // ── Status transition vocabulary ─────────────────────────────────

    test('statusDef returns correct def for known status', () {
      final t = TemplateRegistry.get('task');
      final def = t.statusDef('blocked');
      expect(def.label, 'Blocked');
    });

    test('statusDef returns first status as fallback for unknown value', () {
      final t = TemplateRegistry.get('simple');
      final def = t.statusDef('unknown_status');
      expect(def.value, t.statuses.first.value);
    });
  });
}
