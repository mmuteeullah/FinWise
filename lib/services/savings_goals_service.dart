import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/savings_goal.dart';
import 'database_helper.dart';

class SavingsGoalsService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  static const String tableSavingsGoals = 'savings_goals';

  // Create savings goals table
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSavingsGoals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL,
        target_date TEXT NOT NULL,
        emoji TEXT NOT NULL,
        category INTEGER NOT NULL,
        is_completed INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_goals_active ON $tableSavingsGoals (is_completed)
    ''');
  }

  // Create a new goal
  Future<SavingsGoal> createGoal({
    required String name,
    required String description,
    required double targetAmount,
    required DateTime targetDate,
    String? emoji,
    GoalCategory? category,
  }) async {
    final goal = SavingsGoal(
      id: _uuid.v4(),
      name: name,
      description: description,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      targetDate: targetDate,
      emoji: emoji ?? (category?.defaultEmoji ?? '🎯'),
      category: category ?? GoalCategory.other,
      isCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final db = await _db.database;
    await db.insert(
      tableSavingsGoals,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return goal;
  }

  // Get all goals
  Future<List<SavingsGoal>> getAllGoals() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSavingsGoals,
      orderBy: 'is_completed ASC, target_date ASC',
    );
    return List.generate(maps.length, (i) => SavingsGoal.fromMap(maps[i]));
  }

  // Get active goals
  Future<List<SavingsGoal>> getActiveGoals() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSavingsGoals,
      where: 'is_completed = ?',
      whereArgs: [0],
      orderBy: 'target_date ASC',
    );
    return List.generate(maps.length, (i) => SavingsGoal.fromMap(maps[i]));
  }

  // Get completed goals
  Future<List<SavingsGoal>> getCompletedGoals() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSavingsGoals,
      where: 'is_completed = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => SavingsGoal.fromMap(maps[i]));
  }

  // Get goal by ID
  Future<SavingsGoal?> getGoalById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSavingsGoals,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return SavingsGoal.fromMap(maps.first);
  }

  // Update goal progress
  Future<void> updateProgress(String id, double amount) async {
    final goal = await getGoalById(id);
    if (goal == null) return;

    final newAmount = (goal.currentAmount + amount).clamp(0.0, goal.targetAmount);
    final isCompleted = newAmount >= goal.targetAmount;

    final db = await _db.database;
    await db.update(
      tableSavingsGoals,
      {
        'current_amount': newAmount,
        'is_completed': isCompleted ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Set goal progress (absolute value)
  Future<void> setProgress(String id, double amount) async {
    final goal = await getGoalById(id);
    if (goal == null) return;

    final newAmount = amount.clamp(0.0, goal.targetAmount);
    final isCompleted = newAmount >= goal.targetAmount;

    final db = await _db.database;
    await db.update(
      tableSavingsGoals,
      {
        'current_amount': newAmount,
        'is_completed': isCompleted ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update goal
  Future<void> updateGoal(SavingsGoal goal) async {
    final db = await _db.database;
    await db.update(
      tableSavingsGoals,
      goal.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  // Mark goal as completed
  Future<void> markCompleted(String id) async {
    final db = await _db.database;
    await db.update(
      tableSavingsGoals,
      {
        'is_completed': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete goal
  Future<void> deleteGoal(String id) async {
    final db = await _db.database;
    await db.delete(
      tableSavingsGoals,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final all = await getAllGoals();
    final active = all.where((g) => !g.isCompleted).toList();
    final completed = all.where((g) => g.isCompleted).toList();

    final totalTargetAmount = active.fold<double>(
      0.0,
      (sum, goal) => sum + goal.targetAmount,
    );

    final totalSavedAmount = active.fold<double>(
      0.0,
      (sum, goal) => sum + goal.currentAmount,
    );

    final totalRemainingAmount = active.fold<double>(
      0.0,
      (sum, goal) => sum + goal.remainingAmount,
    );

    final overallProgress = totalTargetAmount > 0
        ? (totalSavedAmount / totalTargetAmount) * 100
        : 0.0;

    return {
      'totalGoals': all.length,
      'activeGoals': active.length,
      'completedGoals': completed.length,
      'totalTargetAmount': totalTargetAmount,
      'totalSavedAmount': totalSavedAmount,
      'totalRemainingAmount': totalRemainingAmount,
      'overallProgress': overallProgress,
    };
  }

  // Get goals approaching deadline (within 30 days)
  Future<List<SavingsGoal>> getGoalsApproachingDeadline() async {
    final active = await getActiveGoals();
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    return active.where((goal) {
      return goal.targetDate.isAfter(now) &&
             goal.targetDate.isBefore(thirtyDaysLater) &&
             !goal.isCompleted;
    }).toList();
  }

  // Get overdue goals
  Future<List<SavingsGoal>> getOverdueGoals() async {
    final active = await getActiveGoals();
    return active.where((goal) => goal.isOverdue).toList();
  }

  // Get goals off track
  Future<List<SavingsGoal>> getGoalsOffTrack() async {
    final active = await getActiveGoals();
    return active.where((goal) => !goal.isOnTrack && !goal.isOverdue).toList();
  }
}
