import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../services/category_service.dart';
import '../models/category.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final CategoryService _categoryService = CategoryService.instance;
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryService.getAllCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final emojiController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Pets, Gifts, Insurance',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji (optional)',
                hintText: 'e.g., =6, <�, =�',
              ),
              maxLength: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a category name')),
                );
                return;
              }

              final error = await _categoryService.validateCategoryName(name);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _categoryService.addCategory(
          name: nameController.text.trim(),
          iconEmoji: emojiController.text.trim().isEmpty ? null : emojiController.text.trim(),
          colorHex: 'FF9800', // Default orange
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${nameController.text.trim()}"')),
        );
        _loadCategories();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleCategoryActive(Category category) async {
    try {
      if (category.isActive) {
        // Check if category has budgets or transactions
        final hasBudgets = await _categoryService.categoryHasBudgets(category.name);
        final hasTransactions = await _categoryService.categoryHasTransactions(category.name);

        if (hasBudgets || hasTransactions) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Deactivate Category?'),
              content: Text(
                'This category has ${hasBudgets ? 'budgets' : ''}'
                '${hasBudgets && hasTransactions ? ' and ' : ''}'
                '${hasTransactions ? 'transactions' : ''}.\n\n'
                'Deactivating will hide it from the app, but preserve existing data.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Deactivate'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }

        await _categoryService.deleteCategory(category.id);
      } else {
        await _categoryService.restoreCategory(category.id);
      }
      _loadCategories();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = _categories.where((c) => c.isActive).toList();
    final inactiveCategories = _categories.where((c) => !c.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: AppTheme.purple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.backgroundGradient(context),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Add Category Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Custom Category'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active Categories
                  Text(
                    'Active Categories (${activeCategories.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...activeCategories.map((cat) => _buildCategoryTile(cat)),

                  if (inactiveCategories.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Inactive Categories (${inactiveCategories.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...inactiveCategories.map((cat) => _buildCategoryTile(cat)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryTile(Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: category.isActive
          ? Colors.white.withOpacity(0.1)
          : Colors.white.withOpacity(0.05),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              category.iconEmoji ?? '=�',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              category.name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                decoration: category.isActive ? null : TextDecoration.lineThrough,
              ),
            ),
            if (category.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEFAULT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: category.isDefault
            ? Chip(
                label: const Text('System', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.grey.withOpacity(0.2),
              )
            : Switch(
                value: category.isActive,
                onChanged: (_) => _toggleCategoryActive(category),
                activeColor: AppTheme.purple,
              ),
      ),
    );
  }
}
