import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/budget.dart';
import 'database_helper.dart';

class BudgetService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  // Table name
  static const String tableBudgets = 'budgets';

  // Create budgets table
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableBudgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL UNIQUE,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        rollover_enabled INTEGER DEFAULT 0,
        rolled_over_amount REAL DEFAULT 0.0
      )
    ''');
  }

  // Insert default budgets
  Future<void> insertDefaultBudgets() async {
    final defaults = {
      'Food & Dining': 15000.0,
      'Shopping': 10000.0,
      'Transportation': 5000.0,
      'Entertainment': 8000.0,
      'Bills & Utilities': 12000.0,
      'Healthcare': 5000.0,
    };

    for (final entry in defaults.entries) {
      final budget = Budget(
        id: _uuid.v4(),
        category: entry.key,
        amount: entry.value,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await setBudget(budget);
    }
  }

  // Get all budgets
  Future<List<Budget>> getAllBudgets() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableBudgets,
      orderBy: 'category ASC',
    );
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  // Get budget by category
  Future<Budget?> getBudgetByCategory(String category) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableBudgets,
      where: 'category = ?',
      whereArgs: [category],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Budget.fromMap(maps.first);
  }

  // Set/Update budget
  Future<void> setBudget(Budget budget) async {
    final db = await _db.database;

    // Check if budget exists for this category
    final existing = await getBudgetByCategory(budget.category);

    if (existing != null) {
      // Update existing budget
      await db.update(
        tableBudgets,
        budget.copyWith(
          id: existing.id,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      // Insert new budget
      await db.insert(
        tableBudgets,
        budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Update budget amount for a category
  Future<void> updateBudgetAmount(String category, double amount) async {
    final existing = await getBudgetByCategory(category);

    if (existing != null) {
      await setBudget(existing.copyWith(
        amount: amount,
        updatedAt: DateTime.now(),
      ));
    } else {
      // Create new budget if doesn't exist
      final budget = Budget(
        id: _uuid.v4(),
        category: category,
        amount: amount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await setBudget(budget);
    }
  }

  // Delete budget
  Future<void> deleteBudget(String id) async {
    final db = await _db.database;
    await db.delete(
      tableBudgets,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete budget by category
  Future<void> deleteBudgetByCategory(String category) async {
    final db = await _db.database;
    await db.delete(
      tableBudgets,
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  // Get budgets as map (category -> amount)
  Future<Map<String, double>> getBudgetsMap() async {
    final budgets = await getAllBudgets();
    return {for (var b in budgets) b.category: b.amount};
  }

  // Check if budgets are empty (first time setup)
  Future<bool> areBudgetsEmpty() async {
    final budgets = await getAllBudgets();
    return budgets.isEmpty;
  }

  // Initialize budgets if empty
  Future<void> initializeBudgetsIfEmpty() async {
    if (await areBudgetsEmpty()) {
      await insertDefaultBudgets();
    }
  }

  // Reset all budgets to defaults
  Future<void> resetToDefaults() async {
    final db = await _db.database;
    await db.delete(tableBudgets);
    await insertDefaultBudgets();
  }

  // Toggle rollover for a specific budget
  Future<void> toggleRollover(String budgetId, bool enabled) async {
    final db = await _db.database;
    await db.update(
      tableBudgets,
      {
        'rollover_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [budgetId],
    );
  }

  // Process monthly rollover for all budgets
  // This should be called at the start of each month
  Future<void> processMonthlyRollover(Map<String, double> currentMonthSpending) async {
    final budgets = await getAllBudgets();
    final db = await _db.database;
    final now = DateTime.now();

    for (final budget in budgets) {
      if (!budget.rolloverEnabled) {
        // Reset rolled over amount if rollover is disabled
        if (budget.rolledOverAmount != 0) {
          await db.update(
            tableBudgets,
            {
              'rolled_over_amount': 0.0,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [budget.id],
          );
        }
        continue;
      }

      // Calculate unused amount from last month
      final spent = currentMonthSpending[budget.category] ?? 0.0;
      final totalAvailable = budget.totalBudget;
      final unused = (totalAvailable - spent).clamp(0.0, double.infinity);

      // Update rolled over amount for next month
      await db.update(
        tableBudgets,
        {
          'rolled_over_amount': unused,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [budget.id],
      );
    }
  }

  // Clear rollover for a specific budget
  Future<void> clearRollover(String budgetId) async {
    final db = await _db.database;
    await db.update(
      tableBudgets,
      {
        'rolled_over_amount': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [budgetId],
    );
  }
}
