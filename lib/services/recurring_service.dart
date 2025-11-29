import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as models;
import 'database_helper.dart';

class RecurringService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  static const String tableRecurring = 'recurring_transactions';

  // Create recurring transactions table
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableRecurring (
        id TEXT PRIMARY KEY,
        merchant TEXT NOT NULL,
        category TEXT NOT NULL,
        average_amount REAL NOT NULL,
        frequency INTEGER NOT NULL,
        first_occurrence TEXT NOT NULL,
        last_occurrence TEXT NOT NULL,
        next_expected_date TEXT,
        occurrence_count INTEGER NOT NULL,
        is_active INTEGER NOT NULL,
        frequency_type INTEGER NOT NULL,
        confidence_score REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_recurring_merchant ON $tableRecurring (merchant)
    ''');

    await db.execute('''
      CREATE INDEX idx_recurring_active ON $tableRecurring (is_active)
    ''');
  }

  // Detect recurring transactions from all transactions
  Future<List<RecurringTransaction>> detectRecurringTransactions(
    List<models.Transaction> transactions,
  ) async {
    // Group transactions by merchant
    final Map<String, List<models.Transaction>> merchantGroups = {};

    for (final transaction in transactions) {
      if (transaction.type == models.TransactionType.debit && transaction.merchant.isNotEmpty) {
        if (!merchantGroups.containsKey(transaction.merchant)) {
          merchantGroups[transaction.merchant] = [];
        }
        merchantGroups[transaction.merchant]!.add(transaction);
      }
    }

    final List<RecurringTransaction> recurringList = [];

    // Analyze each merchant group
    for (final entry in merchantGroups.entries) {
      final merchant = entry.key;
      final merchantTransactions = entry.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Need at least 3 transactions to detect pattern
      if (merchantTransactions.length < 3) continue;

      // Calculate intervals between transactions
      final List<int> intervals = [];
      for (int i = 1; i < merchantTransactions.length; i++) {
        final days = merchantTransactions[i]
            .timestamp
            .difference(merchantTransactions[i - 1].timestamp)
            .inDays;
        intervals.add(days);
      }

      // Check if intervals are consistent (within 20% variance)
      if (intervals.isEmpty) continue;

      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      final maxDeviation = avgInterval * 0.2; // 20% tolerance

      bool isRecurring = intervals.every((interval) {
        return (interval - avgInterval).abs() <= maxDeviation;
      });

      if (!isRecurring) continue;

      // Calculate average amount
      final amounts = merchantTransactions.map((t) => t.amount ?? 0.0).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;

      // Calculate confidence score based on:
      // - Number of occurrences
      // - Consistency of intervals
      // - Consistency of amounts
      final occurrenceScore = (merchantTransactions.length / 12).clamp(0.0, 1.0); // Max at 12 occurrences

      final intervalVariance = intervals.map((i) => (i - avgInterval).abs()).reduce((a, b) => a + b) / intervals.length;
      final intervalScore = (1 - (intervalVariance / avgInterval)).clamp(0.0, 1.0);

      final amountVariance = amounts.map((a) => (a - avgAmount).abs()).reduce((a, b) => a + b) / amounts.length;
      final amountScore = (1 - (amountVariance / avgAmount)).clamp(0.0, 1.0);

      final confidenceScore = (occurrenceScore * 0.3 + intervalScore * 0.4 + amountScore * 0.3);

      // Only include if confidence is above 60%
      if (confidenceScore < 0.6) continue;

      final frequencyType = getFrequencyType(avgInterval.round());
      final lastTransaction = merchantTransactions.last;
      final nextExpected = lastTransaction.timestamp.add(Duration(days: avgInterval.round()));

      final recurring = RecurringTransaction(
        id: _uuid.v4(),
        merchant: merchant,
        category: lastTransaction.category,
        averageAmount: avgAmount,
        frequency: avgInterval.round(),
        firstOccurrence: merchantTransactions.first.timestamp,
        lastOccurrence: lastTransaction.timestamp,
        nextExpectedDate: nextExpected,
        occurrenceCount: merchantTransactions.length,
        isActive: true,
        frequencyType: frequencyType,
        confidenceScore: confidenceScore,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      recurringList.add(recurring);
    }

    return recurringList;
  }

  // Save recurring transaction
  Future<void> saveRecurring(RecurringTransaction recurring) async {
    final db = await _db.database;

    // Check if already exists for this merchant
    final existing = await getByMerchant(recurring.merchant);

    if (existing != null) {
      // Update existing
      await db.update(
        tableRecurring,
        recurring.copyWith(
          id: existing.id,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      // Insert new
      await db.insert(
        tableRecurring,
        recurring.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Get all recurring transactions
  Future<List<RecurringTransaction>> getAll() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableRecurring,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'next_expected_date ASC',
    );
    return List.generate(maps.length, (i) => RecurringTransaction.fromMap(maps[i]));
  }

  // Get recurring by merchant
  Future<RecurringTransaction?> getByMerchant(String merchant) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableRecurring,
      where: 'merchant = ? AND is_active = ?',
      whereArgs: [merchant, 1],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return RecurringTransaction.fromMap(maps.first);
  }

  // Get upcoming recurring transactions (next 7 days)
  Future<List<RecurringTransaction>> getUpcoming() async {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));

    final all = await getAll();
    return all.where((r) {
      if (r.nextExpectedDate == null) return false;
      return r.nextExpectedDate!.isAfter(now) &&
             r.nextExpectedDate!.isBefore(sevenDaysLater);
    }).toList();
  }

  // Get overdue recurring transactions
  Future<List<RecurringTransaction>> getOverdue() async {
    final now = DateTime.now();
    final all = await getAll();
    return all.where((r) {
      if (r.nextExpectedDate == null) return false;
      return r.nextExpectedDate!.isBefore(now);
    }).toList();
  }

  // Mark as inactive
  Future<void> markInactive(String id) async {
    final db = await _db.database;
    await db.update(
      tableRecurring,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete recurring transaction
  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      tableRecurring,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Refresh recurring transactions by re-analyzing
  Future<int> refreshRecurring(List<models.Transaction> allTransactions) async {
    final detected = await detectRecurringTransactions(allTransactions);

    for (final recurring in detected) {
      await saveRecurring(recurring);
    }

    return detected.length;
  }

  // Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final all = await getAll();
    final upcoming = await getUpcoming();
    final overdue = await getOverdue();

    final totalMonthly = all
        .where((r) => r.frequencyType == RecurringFrequency.monthly)
        .fold<double>(0.0, (sum, r) => sum + r.averageAmount);

    return {
      'total': all.length,
      'upcoming': upcoming.length,
      'overdue': overdue.length,
      'totalMonthlyAmount': totalMonthly,
    };
  }
}
