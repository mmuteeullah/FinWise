import '../models/category.dart';
import 'database_helper.dart';

/// Service for managing categories (CRUD operations)
class CategoryService {
  static final CategoryService instance = CategoryService._internal();
  factory CategoryService() => instance;
  CategoryService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Get all active categories
  Future<List<Category>> getActiveCategories() async {
    final db = await _db.database;
    final result = await db.query(
      'categories',
      where: 'is_active = 1',
      orderBy: 'is_default DESC, name ASC',
    );
    return result.map((map) => Category.fromMap(map)).toList();
  }

  /// Get all categories (including inactive)
  Future<List<Category>> getAllCategories() async {
    final db = await _db.database;
    final result = await db.query(
      'categories',
      orderBy: 'is_default DESC, is_active DESC, name ASC',
    );
    return result.map((map) => Category.fromMap(map)).toList();
  }

  /// Get active category names only (for LLM)
  Future<List<String>> getActiveCategoryNames() async {
    final categories = await getActiveCategories();
    return categories.map((cat) => cat.name).toList();
  }

  /// Get category by ID
  Future<Category?> getCategoryById(String id) async {
    final db = await _db.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Category.fromMap(result.first);
  }

  /// Get category by name
  Future<Category?> getCategoryByName(String name) async {
    final db = await _db.database;
    final result = await db.query(
      'categories',
      where: 'name = ? AND is_active = 1',
      whereArgs: [name],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Category.fromMap(result.first);
  }

  /// Add new custom category
  Future<Category> addCategory({
    required String name,
    String? iconEmoji,
    String? colorHex,
  }) async {
    final db = await _db.database;

    // Check if category name already exists (even if inactive)
    final existing = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception('Category "$name" already exists');
    }

    final now = DateTime.now();
    final category = Category(
      id: '${now.millisecondsSinceEpoch}_${name.hashCode}',
      name: name,
      isDefault: false,
      isActive: true,
      iconEmoji: iconEmoji,
      colorHex: colorHex,
      createdAt: now,
    );

    await db.insert('categories', category.toMap());
    print(' Added custom category: $name');
    return category;
  }

  /// Update category
  Future<void> updateCategory(Category category) async {
    final db = await _db.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    print(' Updated category: ${category.name}');
  }

  /// Soft delete category (mark as inactive)
  /// Note: Cannot delete default categories
  Future<bool> deleteCategory(String id) async {
    final db = await _db.database;

    // Check if it's a default category
    final category = await getCategoryById(id);
    if (category == null) {
      throw Exception('Category not found');
    }

    if (category.isDefault) {
      throw Exception('Cannot delete default categories');
    }

    // Soft delete: mark as inactive
    await db.update(
      'categories',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    print(' Deleted category: ${category.name}');
    return true;
  }

  /// Restore deleted category (mark as active)
  Future<void> restoreCategory(String id) async {
    final db = await _db.database;
    await db.update(
      'categories',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    print(' Restored category');
  }

  /// Check if category has any budgets
  Future<bool> categoryHasBudgets(String categoryName) async {
    final db = await _db.database;
    final result = await db.query(
      'budgets',
      where: 'category = ?',
      whereArgs: [categoryName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Check if category has any transactions
  Future<bool> categoryHasTransactions(String categoryName) async {
    final db = await _db.database;
    final result = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [categoryName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get transaction count for a category
  Future<int> getCategoryTransactionCount(String categoryName) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE category = ?',
      [categoryName],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Validate category name (used for form validation)
  Future<String?> validateCategoryName(String name, {String? excludeId}) async {
    if (name.trim().isEmpty) {
      return 'Category name cannot be empty';
    }

    if (name.trim().length < 2) {
      return 'Category name must be at least 2 characters';
    }

    if (name.trim().length > 50) {
      return 'Category name must be less than 50 characters';
    }

    // Check for duplicates
    final db = await _db.database;
    final whereClause = excludeId != null ? 'name = ? AND id != ?' : 'name = ?';
    final whereArgs = excludeId != null ? [name.trim(), excludeId] : [name.trim()];

    final result = await db.query(
      'categories',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (result.isNotEmpty) {
      return 'Category "$name" already exists';
    }

    return null;
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final allCategories = await getAllCategories();
    final activeCategories = allCategories.where((c) => c.isActive).toList();
    final customCategories = allCategories.where((c) => !c.isDefault).toList();

    return {
      'total': allCategories.length,
      'active': activeCategories.length,
      'inactive': allCategories.length - activeCategories.length,
      'custom': customCategories.length,
      'default': allCategories.where((c) => c.isDefault).length,
    };
  }
}
