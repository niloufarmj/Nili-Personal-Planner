import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'groceries_service.dart';
import 'ingredient_repository.dart';

final _allIngredientsProvider = StreamProvider.autoDispose<List<Ingredient>>(
  (ref) => ref.watch(ingredientRepositoryProvider).watchAll(),
);

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  static const _categories = [
    'all',
    'produce',
    'dairy',
    'pantry',
    'meat',
    'spices',
    'other',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(_allIngredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients Catalog'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_ingredient_fab',
        onPressed: () => _showAddEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Ingredient'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(_categoryLabel(cat)),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: ingredientsAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                final filtered = list.where((item) {
                  final matchesQuery = _searchQuery.isEmpty ||
                      item.name.toLowerCase().contains(_searchQuery);
                  final matchesCat = _selectedCategory == 'all' ||
                      (item.category ?? 'other').toLowerCase() == _selectedCategory;
                  return matchesQuery && matchesCat;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.kitchen_outlined,
                    message: _searchQuery.isNotEmpty
                        ? 'No ingredient found matching "$_searchQuery"'
                        : 'No ingredients in catalog',
                    hint: 'Tap + Add Ingredient to create one',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final hasImage =
                        item.image != null && File(item.image!).existsSync();
                    final estCostStr = item.estimatedCost != null
                        ? ' · Est. \$${item.estimatedCost!.toStringAsFixed(2)}'
                        : '';

                    return AppCard(
                      child: ListTile(
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${_categoryLabel(item.category ?? 'other')}'
                          '${item.proteinPer100g != null ? ' · ${item.proteinPer100g}g protein/100g' : ''}'
                          '${item.kcalPer100g != null ? ' · ${item.kcalPer100g} kcal/100g' : ''}'
                          '$estCostStr',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Small circular ingredient image on the right side
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  DesignTokens.peach.withValues(alpha: 0.2),
                              backgroundImage:
                                  hasImage ? FileImage(File(item.image!)) : null,
                              child: !hasImage
                                  ? Text(
                                      _categoryEmoji(item.category),
                                      style: const TextStyle(fontSize: 14),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddEditDialog(context, item: item);
                                } else if (val == 'delete') {
                                  _confirmDelete(context, item);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _categoryLabel(String cat) => switch (cat) {
        'produce' => 'Produce 🥗',
        'dairy' => 'Dairy 🥛',
        'pantry' => 'Pantry 🌾',
        'meat' => 'Meat & Fish 🥩',
        'spices' => 'Spices & Oils 🧂',
        'other' => 'Other 📦',
        _ => 'All',
      };

  static String _categoryEmoji(String? cat) => switch (cat?.toLowerCase()) {
        'produce' => '🥗',
        'dairy' => '🥛',
        'pantry' => '🌾',
        'meat' => '🥩',
        'spices' => '🧂',
        _ => '📦',
      };

  void _showAddEditDialog(BuildContext context, {Ingredient? item}) {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final kcalCtrl =
        TextEditingController(text: item?.kcalPer100g?.toString() ?? '');
    final proteinCtrl =
        TextEditingController(text: item?.proteinPer100g?.toString() ?? '');
    final estCostCtrl =
        TextEditingController(text: item?.estimatedCost?.toString() ?? '');
    String cat = item?.category ?? 'produce';
    String? imagePath = item?.image;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Ingredient' : 'Edit Ingredient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image picker avatar
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setDialogState(() => imagePath = picked.path);
                    }
                  },
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: DesignTokens.peach.withValues(alpha: 0.2),
                    backgroundImage: imagePath != null &&
                            File(imagePath!).existsSync()
                        ? FileImage(File(imagePath!))
                        : null,
                    child: imagePath == null || !File(imagePath!).existsSync()
                        ? const Icon(Icons.add_a_photo, size: 24)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap to select image',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .where((c) => c != 'all')
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(_categoryLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => cat = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kcalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Calories (kcal / 100g)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proteinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Protein (g / 100g)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: estCostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Est. Cost per unit / pack (\$) (optional)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final repo = ref.read(ingredientRepositoryProvider);
                if (item == null) {
                  await repo.create(
                    name: name,
                    category: cat,
                    kcalPer100g: double.tryParse(kcalCtrl.text),
                    proteinPer100g: double.tryParse(proteinCtrl.text),
                    image: imagePath,
                    estimatedCost: double.tryParse(estCostCtrl.text),
                  );
                } else {
                  await repo.update(
                    item.copyWith(
                      name: name,
                      category: Value(cat),
                      kcalPer100g: Value(double.tryParse(kcalCtrl.text)),
                      proteinPer100g: Value(double.tryParse(proteinCtrl.text)),
                      image: Value(imagePath),
                      estimatedCost: Value(double.tryParse(estCostCtrl.text)),
                    ),
                  );
                }
                // Sync all ingredients to Groceries list so the new image is present
                await ref
                    .read(groceriesServiceProvider)
                    .syncAllIngredientsToGroceriesList();

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Ingredient item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${item.name}"?'),
        content: const Text('This will remove the item from your catalogue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(ingredientRepositoryProvider).delete(item.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
