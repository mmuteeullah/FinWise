import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart' as models;
import 'budget_service.dart';
import 'recurring_service.dart';
import 'savings_goals_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('transactions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12, // Added Uncategorized category
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to transactions table
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN autoCategorized INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN categoryRuleId TEXT
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN categoryConfidence REAL DEFAULT 0.0
      ''');

      // Create category rules table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_rules (
          id TEXT PRIMARY KEY,
          keyword TEXT NOT NULL,
          category TEXT NOT NULL,
          priority INTEGER DEFAULT 0,
          isUserDefined INTEGER DEFAULT 0,
          isLearned INTEGER DEFAULT 0,
          confidence REAL DEFAULT 1.0,
          matchCount INTEGER DEFAULT 0,
          lastUsed INTEGER,
          UNIQUE(keyword, category)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_keyword ON category_rules (keyword)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_priority ON category_rules (priority DESC)
      ''');
    }

    if (oldVersion < 3) {
      // Create budgets table
      await BudgetService.createTable(db);
    }

    if (oldVersion < 4) {
      // Create recurring transactions and savings goals tables
      await RecurringService.createTable(db);
      await SavingsGoalsService.createTable(db);
    }

    if (oldVersion < 5) {
      // Add hybrid parser fields to transactions table
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN transactionId TEXT
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN parserConfidence REAL DEFAULT 0.0
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN parserType TEXT
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN parseTime REAL
      ''');
    }

    if (oldVersion < 6) {
      // Add parsingError field for LLM integration
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN parsingError TEXT
      ''');
    }

    if (oldVersion < 7) {
      // Add currency fields for multi-currency support
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN originalCurrency TEXT
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN originalAmount REAL
      ''');

      // Create exchange rates table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exchange_rates (
          currency TEXT PRIMARY KEY,
          rate REAL NOT NULL,
          lastUpdated INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      // Add budget rollover fields
      await db.execute('''
        ALTER TABLE budgets ADD COLUMN rollover_enabled INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE budgets ADD COLUMN rolled_over_amount REAL DEFAULT 0.0
      ''');
    }

    if (oldVersion < 9) {
      // Create email accounts table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS email_accounts (
          id TEXT PRIMARY KEY,
          provider TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          display_name TEXT NOT NULL,
          photo_url TEXT,
          connected_at TEXT NOT NULL,
          last_synced_at TEXT,
          is_active INTEGER DEFAULT 1,
          emails_processed INTEGER DEFAULT 0
        )
      ''');

      // Create email messages table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS email_messages (
          id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          from_email TEXT NOT NULL,
          from_name TEXT NOT NULL,
          subject TEXT NOT NULL,
          snippet TEXT,
          text_body TEXT,
          html_body TEXT,
          received_at TEXT NOT NULL,
          is_processed INTEGER DEFAULT 0,
          is_transactional INTEGER DEFAULT 0,
          transaction_id TEXT,
          labels TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (account_id) REFERENCES email_accounts (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for email messages
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_email_messages_account ON email_messages (account_id)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_email_messages_received ON email_messages (received_at DESC)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_email_messages_processed ON email_messages (is_processed)
      ''');
    }

    if (oldVersion < 10) {
      // Create card preferences table for card management
      await db.execute('''
        CREATE TABLE IF NOT EXISTS card_preferences (
          account_last_digits TEXT PRIMARY KEY,
          is_visible INTEGER NOT NULL DEFAULT 1,
          card_nickname TEXT,
          card_type TEXT DEFAULT 'credit',
          card_issuer TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create index for faster lookups
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_card_visible ON card_preferences (is_visible)
      ''');
    }

    if (oldVersion < 11) {
      // Create categories table for dynamic category management
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT UNIQUE NOT NULL,
          is_default INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          icon_emoji TEXT,
          color_hex TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create index for faster lookups
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_categories_active ON categories (is_active)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_categories_default ON categories (is_default)
      ''');

      // Seed default categories
      final now = DateTime.now().millisecondsSinceEpoch;
      final defaultCategories = [
        {'name': 'Food & Dining', 'emoji': '🍔', 'color': 'FF6B35'},
        {'name': 'Shopping', 'emoji': '🛒', 'color': 'F7931E'},
        {'name': 'Transportation', 'emoji': '🚗', 'color': '4A90E2'},
        {'name': 'Bills & Utilities', 'emoji': '💡', 'color': '7B68EE'},
        {'name': 'Entertainment', 'emoji': '🎬', 'color': 'E91E63'},
        {'name': 'Healthcare', 'emoji': '🏥', 'color': 'E53935'},
        {'name': 'Travel', 'emoji': '✈️', 'color': '00ACC1'},
        {'name': 'Groceries', 'emoji': '🥬', 'color': '43A047'},
        {'name': 'Education', 'emoji': '📚', 'color': '3949AB'},
        {'name': 'Salary', 'emoji': '💰', 'color': '00897B'},
        {'name': 'Investment', 'emoji': '📈', 'color': '1E88E5'},
        {'name': 'Transfer', 'emoji': '↔️', 'color': '757575'},
        {'name': 'Uncategorized', 'emoji': '❓', 'color': 'BDBDBD'},
        {'name': 'Other', 'emoji': '📦', 'color': '9E9E9E'},
      ];

      for (final cat in defaultCategories) {
        final id = DateTime.now().millisecondsSinceEpoch.toString() + cat['name']!.hashCode.toString();
        await db.insert('categories', {
          'id': id,
          'name': cat['name'],
          'is_default': 1,
          'is_active': 1,
          'icon_emoji': cat['emoji'],
          'color_hex': cat['color'],
          'created_at': now,
        });
      }
    }

    if (oldVersion < 12) {
      // Add Uncategorized category for existing v11 users who don't have it yet
      final now = DateTime.now().millisecondsSinceEpoch;
      final uncategorizedExists = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: ['Uncategorized'],
        limit: 1,
      );

      if (uncategorizedExists.isEmpty) {
        final id = now.toString() + 'Uncategorized'.hashCode.toString();
        await db.insert('categories', {
          'id': id,
          'name': 'Uncategorized',
          'is_default': 1,
          'is_active': 1,
          'icon_emoji': '❓',
          'color_hex': 'BDBDBD',
          'created_at': now,
        });
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        rawMessage TEXT NOT NULL,
        amount REAL,
        type INTEGER NOT NULL,
        merchant TEXT NOT NULL,
        category TEXT NOT NULL,
        accountLastDigits TEXT,
        balance REAL,
        timestamp INTEGER NOT NULL,
        isParsed INTEGER NOT NULL,
        isManuallyEdited INTEGER NOT NULL,
        autoCategorized INTEGER DEFAULT 0,
        categoryRuleId TEXT,
        categoryConfidence REAL DEFAULT 0.0,
        transactionId TEXT,
        parserConfidence REAL DEFAULT 0.0,
        parserType TEXT,
        parseTime REAL,
        parsingError TEXT,
        originalCurrency TEXT,
        originalAmount REAL
      )
    ''');

    // Create index on timestamp for faster queries
    await db.execute('''
      CREATE INDEX idx_timestamp ON transactions (timestamp DESC)
    ''');

    // Create index on category for analytics
    await db.execute('''
      CREATE INDEX idx_category ON transactions (category)
    ''');

    // Create category rules table
    await db.execute('''
      CREATE TABLE category_rules (
        id TEXT PRIMARY KEY,
        keyword TEXT NOT NULL,
        category TEXT NOT NULL,
        priority INTEGER DEFAULT 0,
        isUserDefined INTEGER DEFAULT 0,
        isLearned INTEGER DEFAULT 0,
        confidence REAL DEFAULT 1.0,
        matchCount INTEGER DEFAULT 0,
        lastUsed INTEGER,
        UNIQUE(keyword, category)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_keyword ON category_rules (keyword)
    ''');

    await db.execute('''
      CREATE INDEX idx_priority ON category_rules (priority DESC)
    ''');

    // Create budgets table
    await BudgetService.createTable(db);

    // Create recurring transactions table
    await RecurringService.createTable(db);

    // Create savings goals table
    await SavingsGoalsService.createTable(db);

    // Create exchange rates table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exchange_rates (
        currency TEXT PRIMARY KEY,
        rate REAL NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // Create email accounts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS email_accounts (
        id TEXT PRIMARY KEY,
        provider TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        photo_url TEXT,
        connected_at TEXT NOT NULL,
        last_synced_at TEXT,
        is_active INTEGER DEFAULT 1,
        emails_processed INTEGER DEFAULT 0
      )
    ''');

    // Create email messages table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS email_messages (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        from_email TEXT NOT NULL,
        from_name TEXT NOT NULL,
        subject TEXT NOT NULL,
        snippet TEXT,
        text_body TEXT,
        html_body TEXT,
        received_at TEXT NOT NULL,
        is_processed INTEGER DEFAULT 0,
        is_transactional INTEGER DEFAULT 0,
        transaction_id TEXT,
        labels TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES email_accounts (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for email messages
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_email_messages_account ON email_messages (account_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_email_messages_received ON email_messages (received_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_email_messages_processed ON email_messages (is_processed)
    ''');
  }

  /// Insert a new transaction with duplicate detection
  Future<models.Transaction> insertTransaction(models.Transaction transaction) async {
    final db = await database;

    // Check for duplicate transaction
    // Same amount, merchant, date (within same day), and card number = likely duplicate
    final duplicateCheck = await db.query(
      'transactions',
      where: '''
        amount = ? AND
        merchant = ? AND
        DATE(timestamp / 1000, 'unixepoch') = DATE(? / 1000, 'unixepoch') AND
        accountLastDigits = ? AND
        type = ?
      ''',
      whereArgs: [
        transaction.amount,
        transaction.merchant,
        transaction.timestamp.millisecondsSinceEpoch,
        transaction.accountLastDigits,
        transaction.type.toString().split('.').last,
      ],
      limit: 1,
    );

    if (duplicateCheck.isNotEmpty) {
      print('⚠️ Duplicate transaction detected - skipping insert');
      print('   Amount: ${transaction.amount}, Merchant: ${transaction.merchant}, Date: ${transaction.timestamp}');
      // Return existing transaction
      return models.Transaction.fromMap(duplicateCheck.first);
    }

    // No duplicate found, insert new transaction
    await db.insert('transactions', transaction.toMap());
    return transaction;
  }

  /// Get all transactions
  Future<List<models.Transaction>> getAllTransactions() async {
    final db = await database;
    final result = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => models.Transaction.fromMap(map)).toList();
  }

  /// Get transactions within a date range
  Future<List<models.Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => models.Transaction.fromMap(map)).toList();
  }

  /// Get transactions by category
  Future<List<models.Transaction>> getTransactionsByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => models.Transaction.fromMap(map)).toList();
  }

  /// Update a transaction
  Future<int> updateTransaction(models.Transaction transaction) async {
    final db = await database;
    return db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Delete a transaction
  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all transactions
  Future<int> deleteAllTransactions() async {
    final db = await database;
    return db.delete('transactions');
  }

  /// Delete transactions for a specific month
  Future<int> deleteTransactionsByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    return await db.delete(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
  }

  /// Get total spending by category in a date range
  Future<Map<String, double>> getCategoryTotals(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE timestamp BETWEEN ? AND ?
        AND type = ?
        AND amount IS NOT NULL
      GROUP BY category
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
      models.TransactionType.debit.index,
    ]);

    return Map.fromEntries(
      result.map((row) => MapEntry(
            row['category'] as String,
            (row['total'] as num).toDouble(),
          )),
    );
  }

  /// Get total income in a date range
  Future<double> getTotalIncome(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE timestamp BETWEEN ? AND ?
        AND type = ?
        AND amount IS NOT NULL
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
      models.TransactionType.credit.index,
    ]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get total spending in a date range
  Future<double> getTotalSpending(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE timestamp BETWEEN ? AND ?
        AND type = ?
        AND amount IS NOT NULL
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
      models.TransactionType.debit.index,
    ]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get unique card/account numbers with usage count
  /// Smart filtering: excludes XUPI, requires 4 digits, 1+ transactions
  Future<Map<String, int>> getUniqueAccounts() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT accountLastDigits, COUNT(*) as count
      FROM transactions
      WHERE accountLastDigits IS NOT NULL
        AND accountLastDigits != 'XUPI'
        AND LENGTH(accountLastDigits) = 4
      GROUP BY accountLastDigits
      HAVING count >= 1
      ORDER BY count DESC
    ''');

    // Additional validation: ensure all characters are numeric
    final validEntries = <MapEntry<String, int>>[];
    for (final row in result) {
      final digits = row['accountLastDigits'] as String;
      final count = row['count'] as int;

      // Verify it's all digits
      if (RegExp(r'^\d{4}$').hasMatch(digits)) {
        validEntries.add(MapEntry(digits, count));
      }
    }

    return Map.fromEntries(validEntries);
  }

  /// Get spending for a specific month
  Future<double> getMonthlySpending(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE timestamp BETWEEN ? AND ?
        AND type = ?
        AND amount IS NOT NULL
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
      models.TransactionType.debit.index,
    ]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get top merchants by transaction count
  Future<List<String>> getTopMerchants({int limit = 10}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT merchant, COUNT(*) as count
      FROM transactions
      WHERE merchant != 'Unknown Merchant'
      GROUP BY merchant
      ORDER BY count DESC
      LIMIT ?
    ''', [limit]);

    return result.map((row) => row['merchant'] as String).toList();
  }

  // ==================== Card Preference Methods ====================

  bool _cardPrefsTableVerified = false;

  /// Ensure card_preferences table exists (handles failed migrations)
  Future<void> _ensureCardPrefsTableExists() async {
    if (_cardPrefsTableVerified) return;

    final db = await database;

    // Check if table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='card_preferences'"
    );

    if (tables.isEmpty) {
      print('⚠️ card_preferences table missing - creating it now...');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS card_preferences (
          account_last_digits TEXT PRIMARY KEY,
          is_visible INTEGER NOT NULL DEFAULT 1,
          card_nickname TEXT,
          card_type TEXT DEFAULT 'credit',
          card_issuer TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_card_visible ON card_preferences (is_visible)
      ''');

      print('✅ card_preferences table created');
    }

    _cardPrefsTableVerified = true;
  }

  /// Get card preference by account last digits
  Future<Map<String, dynamic>?> getCardPreference(String accountLastDigits) async {
    await _ensureCardPrefsTableExists();
    final db = await database;
    final result = await db.query(
      'card_preferences',
      where: 'account_last_digits = ?',
      whereArgs: [accountLastDigits],
    );

    if (result.isEmpty) return null;
    return result.first;
  }

  /// Get all card preferences
  Future<List<Map<String, dynamic>>> getAllCardPreferences() async {
    await _ensureCardPrefsTableExists();
    final db = await database;
    return await db.query('card_preferences', orderBy: 'created_at DESC');
  }

  /// Get only visible cards
  Future<List<Map<String, dynamic>>> getVisibleCardPreferences() async {
    await _ensureCardPrefsTableExists();
    final db = await database;
    return await db.query(
      'card_preferences',
      where: 'is_visible = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
  }

  /// Insert or update card preference
  Future<void> upsertCardPreference(Map<String, dynamic> cardPref) async {
    await _ensureCardPrefsTableExists();
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if exists
    final existing = await getCardPreference(cardPref['account_last_digits']);

    if (existing == null) {
      // Insert new
      cardPref['created_at'] = now;
      cardPref['updated_at'] = now;
      await db.insert('card_preferences', cardPref);
    } else {
      // Update existing
      cardPref['updated_at'] = now;
      await db.update(
        'card_preferences',
        cardPref,
        where: 'account_last_digits = ?',
        whereArgs: [cardPref['account_last_digits']],
      );
    }
  }

  /// Update card visibility
  Future<void> updateCardVisibility(String accountLastDigits, bool isVisible) async {
    final db = await database;
    await db.update(
      'card_preferences',
      {
        'is_visible': isVisible ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'account_last_digits = ?',
      whereArgs: [accountLastDigits],
    );
  }

  /// Delete card preference
  Future<void> deleteCardPreference(String accountLastDigits) async {
    final db = await database;
    await db.delete(
      'card_preferences',
      where: 'account_last_digits = ?',
      whereArgs: [accountLastDigits],
    );
  }

  /// Get unique accounts WITH card preferences applied
  /// This merges detected accounts with user preferences
  Future<Map<String, Map<String, dynamic>>> getAccountsWithPreferences() async {
    // Get all detected accounts (with smart filtering)
    final detectedAccounts = await getUniqueAccounts();

    // Get all card preferences
    final preferences = await getAllCardPreferences();
    final prefsMap = {for (var pref in preferences) pref['account_last_digits'] as String: pref};

    // Merge: detected accounts + preferences
    final result = <String, Map<String, dynamic>>{};

    // Add detected accounts
    for (final entry in detectedAccounts.entries) {
      final accountDigits = entry.key;
      final transactionCount = entry.value;

      result[accountDigits] = {
        'account_last_digits': accountDigits,
        'transaction_count': transactionCount,
        'is_visible': prefsMap[accountDigits]?['is_visible'] ?? 1,
        'card_nickname': prefsMap[accountDigits]?['card_nickname'],
        'card_type': prefsMap[accountDigits]?['card_type'] ?? 'credit',
        'card_issuer': prefsMap[accountDigits]?['card_issuer'],
        'has_preference': prefsMap.containsKey(accountDigits),
      };
    }

    // Add any preferences for cards that may no longer have transactions
    for (final pref in preferences) {
      final accountDigits = pref['account_last_digits'] as String;
      if (!result.containsKey(accountDigits)) {
        result[accountDigits] = {
          'account_last_digits': accountDigits,
          'transaction_count': 0,
          'is_visible': pref['is_visible'],
          'card_nickname': pref['card_nickname'],
          'card_type': pref['card_type'],
          'card_issuer': pref['card_issuer'],
          'has_preference': true,
        };
      }
    }

    return result;
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
