import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/features/settings/seed/parser/seed_parser.dart';

void main() {
  group('SeedParser Tests', () {
    test('successfully parses real seed.json', () {
      final file = File('assets/seeds/seed.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'seed.json must exist in assets/seeds/',
      );
      final content = file.readAsStringSync();

      final result = SeedParser.parse(content);
      expect(result.data, isNotNull);
      expect(
        result.warnings,
        isEmpty,
        reason: 'Real seed.json should have no warnings.',
      );

      final data = result.data!;
      expect(data.version, equals(1));
      expect(data.tags, isNotEmpty);
      expect(data.collections, isNotEmpty);
      expect(data.ingredientsMaster, isNotEmpty);
      expect(data.workoutPlans, isNotEmpty);
      expect(data.habits, isNotEmpty);
      expect(data.debts, isNotEmpty);
    });

    test(
      'surfaces warnings on malformed dates, bad statuses, unknown templates, and missing titles',
      () {
        const brokenJson = '''
      {
        "version": 1,
        "generated": "invalid-date-format",
        "tags": [],
        "collections": [
          {
            "name": "Invalid Collection 1",
            "template": "unknown-template-name",
            "items_media": [
              {
                "title": "",
                "kind": "movie",
                "status": "wrong-status"
              }
            ]
          },
          {
            "name": "Invalid Collection 2",
            "template": "media",
            "items_media": [
              {
                "title": "Valid Media Title",
                "kind": "movie",
                "status": "wrong-status"
              }
            ],
            "items_job": [
              {
                "title": "Job title",
                "status": "applied",
                "due_date": "2026/06/26"
              }
            ]
          }
        ],
        "ingredients_master": [],
        "workout_plans": [],
        "fitness": {
          "initial_measurement": {
            "date": "invalid-measurement-date",
            "weight_kg": 65.0
          },
          "goals": [
            {
              "metric": "weight_kg",
              "target": 57.0,
              "deadline": "invalid-deadline-date"
            }
          ]
        },
        "habits": [],
        "debts": []
      }
      ''';

        final result = SeedParser.parse(brokenJson);
        expect(result.data, isNotNull);
        expect(result.warnings, isNotEmpty);

        // Verify that specific validation warnings are present
        final warningsJoined = result.warnings.join('\n');
        expect(
          warningsJoined,
          contains("generated' date 'invalid-date-format' is malformed"),
        );
        expect(
          warningsJoined,
          contains("Unknown template 'unknown-template-name'"),
        );
        expect(
          warningsJoined,
          contains('Media item has a missing or empty title'),
        );
        expect(
          warningsJoined,
          contains("Bad status 'wrong-status' for template 'media'"),
        );
        expect(warningsJoined, contains("due_date' '2026/06/26' is malformed"));
        expect(
          warningsJoined,
          contains(
            "initial measurement date 'invalid-measurement-date' is malformed",
          ),
        );
        expect(
          warningsJoined,
          contains("deadline 'invalid-deadline-date' is malformed"),
        );
      },
    );
  });
}
