import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'ingredient_repository.dart';
import 'recipe_repository.dart';

/// Full-screen recipe editor (create or edit).
class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({super.key, this.existingId});
  final int? existingId;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _instructions = TextEditingController();
  String _slot = 'dinner';
  int? _prepMinutes;
  List<String> _tags = [];
  List<_IngRow> _ingredientRows = [];
  bool _loading = true;

  static const _allTags = [
    'quick',
    'prep-ahead',
    'high-protein',
    'reza-shared',
    'needs-oven',
  ];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.existingId != null) {
      final data = await ref
          .read(recipeRepositoryProvider)
          .getWithIngredients(widget.existingId!);
      if (data != null && mounted) {
        _name.text = data.recipe.name;
        _instructions.text = data.recipe.instructions ?? '';
        _slot = data.recipe.mealSlot;
        _prepMinutes = data.recipe.prepMinutes;
        _tags = List.of(data.recipe.tags);
        _ingredientRows = data.rows
            .map(
              (r) => _IngRow(
                ingredient: r.ingredient,
                amount: r.amount.toString(),
                unit: r.unit,
              ),
            )
            .toList();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LinearProgressIndicator(minHeight: 2));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingId == null ? 'New Recipe' : 'Edit Recipe'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Recipe name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Meal slot
            DropdownButtonFormField<String>(
              initialValue: _slot,
              decoration: const InputDecoration(labelText: 'Meal slot'),
              items: const [
                DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                DropdownMenuItem(
                  value: 'post-gym-shake',
                  child: Text('Post-gym shake'),
                ),
                DropdownMenuItem(value: 'any', child: Text('Any')),
              ],
              onChanged: (v) => setState(() => _slot = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              initialValue: _prepMinutes?.toString(),
              decoration: const InputDecoration(
                labelText: 'Prep time (minutes)',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _prepMinutes = int.tryParse(v),
            ),
            const SizedBox(height: 12),

            // Tags
            const SectionHeader(title: 'Tags'),
            Wrap(
              spacing: 8,
              children: _allTags.map((t) {
                final selected = _tags.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _tags.add(t);
                    } else {
                      _tags.remove(t);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Ingredients
            const SectionHeader(title: 'Ingredients'),
            ..._ingredientRows.asMap().entries.map(
              (e) => _IngredientRowWidget(
                row: e.value,
                onChanged: (r) => setState(() => _ingredientRows[e.key] = r),
                onDelete: () => setState(() => _ingredientRows.removeAt(e.key)),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add ingredient'),
              onPressed: _addIngredientRow,
            ),
            const SizedBox(height: 16),

            // Instructions
            TextFormField(
              controller: _instructions,
              decoration: const InputDecoration(labelText: 'Instructions'),
              maxLines: 5,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _addIngredientRow() {
    setState(() {
      _ingredientRows.add(_IngRow(ingredient: null, amount: '', unit: 'g'));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final recipeRepo = ref.read(recipeRepositoryProvider);
    final ingRepo = ref.read(ingredientRepositoryProvider);

    // Resolve ingredients (find-or-create).
    final resolvedRows = <RecipeIngredientRow>[];
    for (final row in _ingredientRows) {
      if (row.ingredient == null && row.ingredientName.isEmpty) continue;
      final name = row.ingredient?.name ?? row.ingredientName;
      await ingRepo.findOrCreate(name);
      final ing = await ingRepo.getByName(name);
      if (ing == null) continue;
      resolvedRows.add(
        RecipeIngredientRow(
          ingredient: ing,
          amount: double.tryParse(row.amount) ?? 0,
          unit: row.unit,
        ),
      );
    }

    if (widget.existingId == null) {
      final id = await recipeRepo.create(
        name: _name.text.trim(),
        mealSlot: _slot,
        prepMinutes: _prepMinutes,
        tags: _tags,
        instructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
      );
      await recipeRepo.setIngredients(id, resolvedRows);
    } else {
      final existing = await recipeRepo.getById(widget.existingId!);
      if (existing != null) {
        await recipeRepo.update(
          existing.copyWith(
            name: _name.text.trim(),
            mealSlot: _slot,
            prepMinutes: Value(_prepMinutes),
            tags: _tags,
            instructions: Value(
              _instructions.text.trim().isEmpty
                  ? null
                  : _instructions.text.trim(),
            ),
          ),
        );
        await recipeRepo.setIngredients(widget.existingId!, resolvedRows);
      }
    }

    if (mounted) Navigator.of(context).pop();
  }
}

// ── Ingredient row model ──────────────────────────────────────────────────────

class _IngRow {
  _IngRow({this.ingredient, required this.amount, required this.unit})
    : ingredientName = ingredient?.name ?? '';
  final Ingredient? ingredient;
  final String ingredientName;
  final String amount;
  final String unit;

  _IngRow copyWith({
    Ingredient? ingredient,
    String? name,
    String? amount,
    String? unit,
  }) => _IngRow(
    ingredient: ingredient ?? this.ingredient,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
  );
}

// ── Ingredient row widget ─────────────────────────────────────────────────────

class _IngredientRowWidget extends ConsumerStatefulWidget {
  const _IngredientRowWidget({
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });
  final _IngRow row;
  final ValueChanged<_IngRow> onChanged;
  final VoidCallback onDelete;

  @override
  ConsumerState<_IngredientRowWidget> createState() =>
      _IngredientRowWidgetState();
}

class _IngredientRowWidgetState extends ConsumerState<_IngredientRowWidget> {
  late final TextEditingController _namCtrl;
  late final TextEditingController _amtCtrl;
  String _unit = 'g';

  @override
  void initState() {
    super.initState();
    _namCtrl = TextEditingController(
      text: widget.row.ingredient?.name ?? widget.row.ingredientName,
    );
    _amtCtrl = TextEditingController(text: widget.row.amount);
    _unit = widget.row.unit;
  }

  @override
  void dispose() {
    _namCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Autocomplete<Ingredient>(
            initialValue: TextEditingValue(text: _namCtrl.text),
            optionsBuilder: (v) async {
              if (v.text.isEmpty) return [];
              return ref.read(ingredientRepositoryProvider).search(v.text);
            },
            displayStringForOption: (i) => i.name,
            onSelected: (i) {
              _namCtrl.text = i.name;
              widget.onChanged(widget.row.copyWith(ingredient: i));
            },
            fieldViewBuilder: (_, ctrl, focus, onSubmit) => TextField(
              controller: ctrl,
              focusNode: focus,
              decoration: const InputDecoration(hintText: 'Ingredient'),
              onChanged: (_) =>
                  widget.onChanged(widget.row.copyWith(name: ctrl.text)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _amtCtrl,
            decoration: const InputDecoration(hintText: 'Amt'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => widget.onChanged(widget.row.copyWith(amount: v)),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 70,
          child: DropdownButton<String>(
            value: _unit,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'g', child: Text('g')),
              DropdownMenuItem(value: 'ml', child: Text('ml')),
              DropdownMenuItem(value: 'pcs', child: Text('pcs')),
              DropdownMenuItem(value: 'tbsp', child: Text('tbsp')),
            ],
            onChanged: (v) {
              setState(() => _unit = v!);
              widget.onChanged(widget.row.copyWith(unit: v));
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: widget.onDelete,
        ),
      ],
    );
  }
}
