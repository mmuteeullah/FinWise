import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import 'database_helper.dart';
import 'transaction_parser.dart';
import 'integrated_transaction_parser.dart';

class TransactionService {
  static const platform = MethodChannel('com.mmuteeullah.finwise/sms');
  final DatabaseHelper _db = DatabaseHelper.instance;
  final IntegratedTransactionParser _integratedParser = IntegratedTransactionParser();

  /// Sync messages from iOS UserDefaults to SQLite database
  /// This parses raw SMS and stores as transactions
  /// Returns a map with sync statistics including duplicate count
  Future<Map<String, int>> syncFromiOS() async {
    int newCount = 0;
    int duplicateCount = 0;
    int errorCount = 0;

    try {
      // Get raw messages from iOS
      final List<dynamic> rawMessages =
          await platform.invokeMethod('getMessages');

      if (rawMessages.isEmpty) return {'new': 0, 'duplicates': 0, 'errors': 0};

      // Parse and save each message
      for (final messageData in rawMessages) {
        final rawText = messageData['text'] as String;

        // Quick check: if this exact SMS text already exists, skip
        final existingByRaw = await _getTransactionByRawMessage(rawText);
        if (existingByRaw != null) {
          duplicateCount++;
          print('Duplicate SMS (by raw text) detected and skipped: "${rawText.substring(0, rawText.length > 50 ? 50 : rawText.length)}..."');
          continue;
        }

        // Try integrated parser (LLM-first with fallback to hybrid/regex)
        Transaction transaction;
        try {
          // Use integrated parser which handles LLM + fallback logic
          final parseResult = await _integratedParser.parse(rawText);

          if (parseResult.success && parseResult.transaction != null) {
            transaction = parseResult.transaction!;
            print('Transaction parsed with ${parseResult.methodName} (confidence: ${(parseResult.confidence * 100).toStringAsFixed(1)}%)');
          } else {
            // If integrated parser failed, use regex parser as fallback
            print('Integrated parser failed, using regex fallback...');
            transaction = TransactionParser.parse(rawText);
            transaction = transaction.copyWith(
              parserType: 'rule-based-fallback',
              parserConfidence: 0.0,
            );
          }
        } catch (e) {
          // Final fallback to regex parser on any error
          print('All parsers failed: $e, using basic fallback parser');
          transaction = TransactionParser.parse(rawText);
          transaction = transaction.copyWith(
            parserType: 'rule-based-fallback',
            parserConfidence: 0.0,
            parsingError: e.toString(),
          );
        }

        // Check for duplicate by transaction ID (if available)
        if (transaction.transactionId != null && transaction.transactionId!.isNotEmpty) {
          final existingById = await _getTransactionByRawMessage('', transactionId: transaction.transactionId);
          if (existingById != null) {
            duplicateCount++;
            print('Duplicate transaction (by ID: ${transaction.transactionId}) detected and skipped');
            continue;
          }
        }

        // Save to database
        try {
          await _db.insertTransaction(transaction);
          newCount++;
        } catch (e) {
          errorCount++;
          print('Failed to insert transaction: $e');
        }
      }

      // Clear the iOS storage after syncing
      await platform.invokeMethod('clearMessages');

      // Log sync summary
      print('SMS Sync Complete: $newCount new, $duplicateCount duplicates, $errorCount errors');

      return {
        'new': newCount,
        'duplicates': duplicateCount,
        'errors': errorCount,
      };
    } on PlatformException catch (e) {
      print("Failed to sync from iOS: '${e.message}'.");
      return {'new': 0, 'duplicates': 0, 'errors': errorCount};
    }
  }

  /// Get all transactions
  /// Set [skipSync] to true if you've already called syncFromiOS()
  Future<List<Transaction>> getAllTransactions({bool skipSync = false}) async {
    // First sync any new messages from iOS (unless already done)
    if (!skipSync) {
      await syncFromiOS();
    }
    return await _db.getAllTransactions();
  }

  /// Get transactions in date range
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    await syncFromiOS();
    return await _db.getTransactionsByDateRange(start, end);
  }

  /// Get transactions by category
  Future<List<Transaction>> getTransactionsByCategory(String category) async {
    return await _db.getTransactionsByCategory(category);
  }

  /// Update transaction (e.g., change category or edit details)
  Future<void> updateTransaction(Transaction transaction, {bool learnCategory = false}) async {
    await _db.updateTransaction(
      transaction.copyWith(
        isManuallyEdited: true,
        autoCategorized: false, // Manual edit overrides auto-categorization
      ),
    );
  }

  /// Add a new transaction
  Future<Transaction> addTransaction(Transaction transaction) async {
    return await _db.insertTransaction(transaction);
  }

  /// Delete transaction
  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
  }

  /// Delete all transactions
  Future<int> deleteAllTransactions() async {
    final count = await _db.deleteAllTransactions();
    // Also clear iOS storage
    try {
      await platform.invokeMethod('clearMessages');
    } catch (e) {
      print("Failed to clear iOS messages: $e");
    }
    return count;
  }

  /// Get spending summary for last 30 days or specific month
  Future<Map<String, double>> getMonthlySpending([int? year, int? month]) async {
    if (year != null && month != null) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);
      return await _db.getCategoryTotals(start, end);
    }

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now;

    return await _db.getCategoryTotals(start, end);
  }

  /// Get total income for last 30 days
  Future<double> getMonthlyIncome([int? year, int? month]) async {
    if (year != null && month != null) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);
      return await _db.getTotalIncome(start, end);
    }

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now;

    return await _db.getTotalIncome(start, end);
  }

  /// Get total spending for last 30 days or specific month
  Future<double> getMonthlyTotalSpending([int? year, int? month]) async {
    if (year != null && month != null) {
      return await _db.getMonthlySpending(year, month);
    }

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now;

    return await _db.getTotalSpending(start, end);
  }

  /// Get latest balance from most recent transaction
  Future<double?> getLatestBalance() async {
    final transactions = await _db.getAllTransactions();
    for (final transaction in transactions) {
      if (transaction.balance != null) {
        return transaction.balance;
      }
    }
    return null;
  }

  /// Get unique card/account numbers with usage count
  Future<Map<String, int>> getUniqueAccounts() async {
    return await _db.getUniqueAccounts();
  }

  /// Get spending for last month
  Future<double> getLastMonthSpending() async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    return await _db.getMonthlySpending(lastMonth.year, lastMonth.month);
  }

  /// Get top merchants
  Future<List<String>> getTopMerchants({int limit = 10}) async {
    return await _db.getTopMerchants(limit: limit);
  }

  /// Get spending by category within date range
  Future<double> getSpendingByCategory(
    String category,
    DateTime start,
    DateTime end,
  ) async {
    final categoryTotals = await _db.getCategoryTotals(start, end);
    return categoryTotals[category] ?? 0.0;
  }

  /// Check if transaction with this raw message or transaction ID already exists
  Future<Transaction?> _getTransactionByRawMessage(String rawMessage, {String? transactionId}) async {
    final allTransactions = await _db.getAllTransactions();
    try {
      // First check by transaction ID if available (more reliable)
      if (transactionId != null && transactionId.isNotEmpty) {
        try {
          final byId = allTransactions.firstWhere(
            (t) => t.transactionId != null && t.transactionId == transactionId,
          );
          if (byId != null) {
            print('Duplicate found by Transaction ID: $transactionId');
            return byId;
          }
        } catch (e) {
          // Not found by ID, continue to check by raw message
        }
      }

      // Fallback to raw message check
      return allTransactions.firstWhere(
        (t) => t.rawMessage == rawMessage,
      );
    } catch (e) {
      return null;
    }
  }

  /// Delete transactions for a specific month
  Future<int> deleteTransactionsByMonth(int year, int month) async {
    return await _db.deleteTransactionsByMonth(year, month);
  }

  /// Get available months that have transactions
  Future<List<DateTime>> getAvailableMonths() async {
    final transactions = await _db.getAllTransactions();
    if (transactions.isEmpty) return [];

    // Get unique year-month combinations
    final monthsSet = <String>{};
    final months = <DateTime>[];

    for (final transaction in transactions) {
      final date = transaction.timestamp;
      final monthKey = '${date.year}-${date.month}';
      if (!monthsSet.contains(monthKey)) {
        monthsSet.add(monthKey);
        months.add(DateTime(date.year, date.month));
      }
    }

    // Sort by date descending (newest first)
    months.sort((a, b) => b.compareTo(a));
    return months;
  }
}
