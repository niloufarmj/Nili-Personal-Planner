import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../../core/services/image_service.dart';
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
  int? _proteinGrams;
  String? _imagePath;
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
        _proteinGrams = data.recipe.proteinGrams;
        _imagePath = data.recipe.image;
        _tags = List.of(data.recipe.tags);
        _ingredientRows = data.rows
            .map(
              (r) => _IngRow(
                ingredient: r.ingredient,
                ingredientName: r.ingredient.name,
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

  Future<void> _pickImage(ImageSource source) async {
    final imageService = ref.read(imageServiceProvider);
    final path = await imageService.pick(source: source);
    if (path != null && mounted) {
      setState(() {
        _imagePath = path;
      });
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LinearProgressIndicator(minHeight: 2));
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            // Recipe Image Card
            GestureDetector(
              onTap: _showImageOptions,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.surfaceDark : DesignTokens.lineLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                  ),
                ),
                child: _imagePath != null && File(_imagePath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(_imagePath!), fit: BoxFit.cover),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Recipe Photo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

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

            // Prep time & Protein row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _prepMinutes?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Prep time (mins)',
                      prefixIcon: Icon(Icons.timer_outlined, size: 18),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _prepMinutes = int.tryParse(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _proteinGrams?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Protein (grams)',
                      prefixIcon: Icon(Icons.fitness_center_outlined, size: 18),
                      suffixText: 'g',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _proteinGrams = int.tryParse(v),
                  ),
                ),
              ],
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
                key: ValueKey(e.value.id),
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
      final name = row.ingredient?.name.trim() ?? row.ingredientName.trim();
      if (name.isEmpty) continue;
      await ingRepo.findOrCreate(name);
      final ing = await ingRepo.getByName(name);
      if (ing == null) continue;
      resolvedRows.add(
        RecipeIngredientRow(
          ingredient: ing,
          amount: double.tryParse(row.amount.trim()) ?? 0,
          unit: row.unit.trim().isEmpty ? 'g' : row.unit.trim(),
        ),
      );
    }

    if (widget.existingId == null) {
      final id = await recipeRepo.create(
        name: _name.text.trim(),
        mealSlot: _slot,
        prepMinutes: _prepMinutes,
        proteinGrams: _proteinGrams,
        tags: _tags,
        instructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
        image: _imagePath,
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
            proteinGrams: Value(_proteinGrams),
            tags: _tags,
            instructions: Value(
              _instructions.text.trim().isEmpty
                  ? null
                  : _instructions.text.trim(),
            ),
            image: Value(_imagePath),
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
  _IngRow({
    String? id,
    this.ingredient,
    String? ingredientName,
    required this.amount,
    required this.unit,
  })  : id = id ?? const Uuid().v4(),
        ingredientName = ingredientName ?? ingredient?.name ?? '';

  final String id;
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
    id: id,
    ingredient: ingredient ?? this.ingredient,
    ingredientName: name ?? (ingredient != null ? ingredient.name : this.ingredientName),
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
  );
}

// ── Ingredient row widget ─────────────────────────────────────────────────────

class _IngredientRowWidget extends ConsumerStatefulWidget {
  const _IngredientRowWidget({
    super.key,
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
  late final TextEditingController _amtCtrl;

  static const _availableUnits = [
    'g',
    'ml',
    'pcs',
    'tbsp',
    'tsp',
    'cup',
    'clove',
    'slice',
    'pinch',
  ];

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController(text: widget.row.amount);
    _amtCtrl.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (_amtCtrl.text != widget.row.amount) {
      widget.onChanged(widget.row.copyWith(amount: _amtCtrl.text));
    }
  }

  @override
  void dispose() {
    _amtCtrl.removeListener(_onAmountChanged);
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _openIngredientPicker(BuildContext context) async {
    final ingRepo = ref.read(ingredientRepositoryProvider);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _IngredientSearchSheet(
        onSelected: (ing) {
          Navigator.pop(ctx);
          widget.onChanged(widget.row.copyWith(ingredient: ing, name: ing.name));
        },
        onAddNew: (newQuery) async {
          Navigator.pop(ctx);
          final id = await ingRepo.findOrCreate(newQuery);
          final ing = await ingRepo.getByName(newQuery);
          if (ing != null) {
            widget.onChanged(widget.row.copyWith(ingredient: ing, name: ing.name));
          } else {
            widget.onChanged(widget.row.copyWith(name: newQuery));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = widget.row.ingredient?.name ??
        (widget.row.ingredientName.isNotEmpty ? widget.row.ingredientName : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Ingredient Selector Box
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _openIngredientPicker(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.surfaceDark : DesignTokens.lineLight.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName ?? 'Select ingredient...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: displayName != null ? FontWeight.w600 : FontWeight.normal,
                          color: displayName != null
                              ? (isDark ? DesignTokens.inkDark : DesignTokens.inkLight)
                              : (isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Amount TextField
          SizedBox(
            width: 50,
            child: TextField(
              controller: _amtCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Amt',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
                  ),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 6),

          // Unit Compact Dropdown
          Container(
            width: 66,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.surfaceDark : DesignTokens.lineLight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _availableUnits.contains(widget.row.unit) ? widget.row.unit : 'g',
                isDense: true,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                ),
                items: _availableUnits
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    widget.onChanged(widget.row.copyWith(unit: v));
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Compact Delete Icon Button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Search & Select Ingredient Modal Sheet ────────────────────────────────────

class _IngredientSearchSheet extends ConsumerStatefulWidget {
  const _IngredientSearchSheet({
    required this.onSelected,
    required this.onAddNew,
  });

  final ValueChanged<Ingredient> onSelected;
  final ValueChanged<String> onAddNew;

  @override
  ConsumerState<_IngredientSearchSheet> createState() =>
      _IngredientSearchSheetState();
}

class _IngredientSearchSheetState extends ConsumerState<_IngredientSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingRepo = ref.watch(ingredientRepositoryProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Select Ingredient',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Search bar
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search or type new ingredient...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _query = val.trim()),
              ),
              const SizedBox(height: 12),

              // Async Ingredient List
              Expanded(
                child: FutureBuilder<List<Ingredient>>(
                  future: _query.isEmpty ? ingRepo.getAll() : ingRepo.search(_query),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    final exactMatch = items.any(
                      (i) => i.name.toLowerCase() == _query.toLowerCase(),
                    );

                    return ListView(
                      controller: scrollController,
                      children: [
                        if (_query.isNotEmpty && !exactMatch) ...[
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: DesignTokens.accentLight,
                              child: Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                            title: Text(
                              'Add "$_query" as new ingredient',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: DesignTokens.accentLight,
                              ),
                            ),
                            subtitle: const Text('Will be saved to your ingredient catalog'),
                            onTap: () => widget.onAddNew(_query),
                          ),
                          const Divider(),
                        ],
                        if (items.isEmpty && _query.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('No ingredients found. Type to search or add.'),
                            ),
                          )
                        else
                          ...items.map(
                            (ing) => ListTile(
                              title: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: ing.category != null ? Text(ing.category!) : null,
                              onTap: () => widget.onSelected(ing),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
