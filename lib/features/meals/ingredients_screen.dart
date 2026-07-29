import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients Catalog'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_ingredient_fab',
        onPressed: () => _showAddEditDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search & Category Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          const SizedBox(height: 8),

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
                        : 'No ingredients in catalogue',
                    hint: 'Tap + to add a new ingredient',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return AppCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isDark
                                  ? DesignTokens.accentDark
                                  : DesignTokens.accentLight)
                              .withValues(alpha: 0.15),
                          child: Text(
                            _categoryEmoji(item.category),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${_categoryLabel(item.category ?? 'other')}'
                          '${item.proteinPer100g != null ? ' · ${item.proteinPer100g}g protein/100g' : ''}'
                          '${item.kcalPer100g != null ? ' · ${item.kcalPer100g} kcal/100g' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showAddEditDialog(context, item: item);
                            } else if (val == 'delete') {
                              _confirmDelete(context, item);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
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

  Future<void> _showAddEditDialog(BuildContext context, {Ingredient? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final kcalCtrl = TextEditingController(text: item?.kcalPer100g?.toString() ?? '');
    final proteinCtrl = TextEditingController(text: item?.proteinPer100g?.toString() ?? '');
    String cat = item?.category ?? 'produce';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Add Ingredient' : 'Edit Ingredient'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: cat,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'produce', child: Text('Produce 🥗')),
                  DropdownMenuItem(value: 'dairy', child: Text('Dairy 🥛')),
                  DropdownMenuItem(value: 'pantry', child: Text('Pantry 🌾')),
                  DropdownMenuItem(value: 'meat', child: Text('Meat & Fish 🥩')),
                  DropdownMenuItem(value: 'spices', child: Text('Spices & Oils 🧂')),
                  DropdownMenuItem(value: 'other', child: Text('Other 📦')),
                ],
                onChanged: (v) => cat = v!,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: kcalCtrl,
                      decoration: const InputDecoration(labelText: 'Kcal/100g'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      decoration: const InputDecoration(labelText: 'Protein/100g (g)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
                );
              } else {
                await repo.update(
                  item.copyWith(
                    name: name,
                    category: Value(cat),
                    kcalPer100g: Value(double.tryParse(kcalCtrl.text)),
                    proteinPer100g: Value(double.tryParse(proteinCtrl.text)),
                  ),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Ingredient item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ingredient'),
        content: Text('Are you sure you want to delete "${item.name}" from your catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(ingredientRepositoryProvider).delete(item.id);
    }
  }
}
