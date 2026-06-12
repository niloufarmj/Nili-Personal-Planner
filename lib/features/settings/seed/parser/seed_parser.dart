import 'dart:convert';
import '../models/seed_models.dart';

class SeedParseResult {
  final SeedData? data;
  final List<String> warnings;

  SeedParseResult({this.data, required this.warnings});
}

class SeedParser {
  static final RegExp _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static const _validTemplates = {
    'simple',
    'chore',
    'shopping',
    'upgrade',
    'task',
    'job',
    'growth',
    'media',
    'probable',
  };

  static const _validStatusesByTemplate = {
    'simple': {'open', 'done'},
    'chore': {'open', 'done'},
    'shopping': {'wanted', 'bought'},
    'upgrade': {'planned', 'done'},
    'task': {'todo', 'in_progress', 'done', 'blocked'},
    'job': {
      'researching',
      'applied',
      'applied-pending',
      'interview',
      'rejected',
      'offer',
    },
    'growth': {'planned', 'active', 'done'},
    'media': {'backlog', 'active', 'done'},
    'probable': {'undecided', 'promoted', 'dropped'},
  };

  static SeedParseResult parse(String jsonContent) {
    final List<String> warnings = [];
    SeedData? data;

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      data = SeedData.fromJson(decoded);

      // Validate root generated date
      if (!_isValidDate(data.generated)) {
        warnings.add(
          "Root: 'generated' date '${data.generated}' is malformed (expected YYYY-MM-DD).",
        );
      }

      // Validate collections
      for (final collection in data.collections) {
        if (!_validTemplates.contains(collection.template)) {
          warnings.add(
            "Collection '${collection.name}': Unknown template '${collection.template}'.",
          );
        }

        // Validate items inside collection based on its template
        final statuses = _validStatusesByTemplate[collection.template] ?? {};

        // Media items
        for (final item in collection.itemsMedia) {
          if (item.title.trim().isEmpty) {
            warnings.add(
              "Collection '${collection.name}': Media item has a missing or empty title.",
            );
          }
          if (statuses.isNotEmpty && !statuses.contains(item.status)) {
            warnings.add(
              "Collection '${collection.name}', Item '${item.title}': Bad status '${item.status}' for template '${collection.template}'.",
            );
          }
        }

        // Shopping items
        for (final item in collection.itemsShopping) {
          if (item.title.trim().isEmpty) {
            warnings.add(
              "Collection '${collection.name}': Shopping item has a missing or empty title.",
            );
          }
          if (statuses.isNotEmpty && !statuses.contains(item.status)) {
            warnings.add(
              "Collection '${collection.name}', Item '${item.title}': Bad status '${item.status}' for template '${collection.template}'.",
            );
          }
        }

        // Job items
        for (final item in collection.itemsJob) {
          if (item.title.trim().isEmpty) {
            warnings.add(
              "Collection '${collection.name}': Job item has a missing or empty title.",
            );
          }
          if (statuses.isNotEmpty && !statuses.contains(item.status)) {
            warnings.add(
              "Collection '${collection.name}', Item '${item.title}': Bad status '${item.status}' for template '${collection.template}'.",
            );
          }
          if (item.dueDate != null && !_isValidDate(item.dueDate!)) {
            warnings.add(
              "Collection '${collection.name}', Item '${item.title}': 'due_date' '${item.dueDate}' is malformed (expected YYYY-MM-DD).",
            );
          }
        }
      }

      // Validate fitness
      final fitness = data.fitness;
      final measurement = fitness.initialMeasurement;
      if (measurement != null) {
        if (!_isValidDate(measurement.date)) {
          warnings.add(
            "Fitness: initial measurement date '${measurement.date}' is malformed (expected YYYY-MM-DD).",
          );
        }
      }

      for (final goal in fitness.goals) {
        if (goal.deadline != null && !_isValidDate(goal.deadline!)) {
          warnings.add(
            "Fitness goal for '${goal.metric}': deadline '${goal.deadline}' is malformed (expected YYYY-MM-DD).",
          );
        }
      }
    } catch (e) {
      warnings.add('Failed to decode JSON: $e');
    }

    return SeedParseResult(data: data, warnings: warnings);
  }

  static bool _isValidDate(String date) {
    if (!_dateRegex.hasMatch(date)) return false;
    return DateTime.tryParse(date) != null;
  }
}
