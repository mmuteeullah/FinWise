import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../utils/currency_converter.dart';

/// Service for fetching and managing exchange rates
///
/// Features:
/// - Live API integration with ExchangeRate-API (free tier)
/// - Local caching with SQLite
/// - Auto-refresh after 24 hours
/// - Manual refresh support
/// - Fallback to static rates on failure
class ExchangeRateService {
  static final ExchangeRateService instance = ExchangeRateService._init();
  final DatabaseHelper _db = DatabaseHelper.instance;

  // API Configuration
  static const String _apiBaseUrl = 'https://api.exchangerate-api.com/v4/latest';
  static const String _baseCurrency = 'INR';
  static const Duration _cacheExpiry = Duration(hours: 24);

  ExchangeRateService._init();

  /// Fetch exchange rates from API
  ///
  /// Returns a map of currency codes to rates (relative to INR)
  /// Throws an exception if the API call fails
  Future<Map<String, double>> _fetchRatesFromApi() async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$_baseCurrency');
      print('🌐 Fetching exchange rates from: $url');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('API request timed out after 10 seconds');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        print('✅ Fetched ${rates.length} exchange rates');

        // Convert rates to double map
        return rates.map((key, value) => MapEntry(
              key,
              (value as num).toDouble(),
            ));
      } else {
        throw Exception('API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching exchange rates: $e');
      rethrow;
    }
  }

  /// Save exchange rates to local database
  Future<void> _saveRatesToDb(Map<String, double> rates) async {
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final entry in rates.entries) {
      batch.insert(
        'exchange_rates',
        {
          'currency': entry.key,
          'rate': entry.value,
          'lastUpdated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('💾 Saved ${rates.length} exchange rates to database');
  }

  /// Get exchange rates from local database
  Future<Map<String, double>?> _getRatesFromDb() async {
    final db = await _db.database;
    final result = await db.query('exchange_rates');

    if (result.isEmpty) {
      print('📭 No cached exchange rates found in database');
      return null;
    }

    // Check if rates are expired (older than 24 hours)
    final firstRate = result.first;
    final lastUpdated = DateTime.fromMillisecondsSinceEpoch(
      firstRate['lastUpdated'] as int,
    );
    final age = DateTime.now().difference(lastUpdated);

    if (age > _cacheExpiry) {
      print('⏰ Cached exchange rates expired (age: ${age.inHours}h)');
      return null;
    }

    print('✅ Found ${result.length} cached exchange rates (age: ${age.inHours}h)');

    return Map.fromEntries(
      result.map((row) => MapEntry(
            row['currency'] as String,
            (row['rate'] as num).toDouble(),
          )),
    );
  }

  /// Get the last update timestamp
  Future<DateTime?> getLastUpdateTime() async {
    final db = await _db.database;
    final result = await db.query(
      'exchange_rates',
      columns: ['lastUpdated'],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return DateTime.fromMillisecondsSinceEpoch(
      result.first['lastUpdated'] as int,
    );
  }

  /// Get exchange rate for a specific currency
  ///
  /// Returns the rate to convert 1 unit of [currency] to INR
  /// Uses cached rates, or static fallback if not available
  Future<double> getRate(String currency) async {
    // Check if INR (base currency)
    if (currency.toUpperCase() == 'INR' || currency == '₹') {
      return 1.0;
    }

    // Try to get from cache
    final rates = await _getRatesFromDb();
    if (rates != null && rates.containsKey(currency.toUpperCase())) {
      final rate = rates[currency.toUpperCase()]!;
      // API returns rates as "1 INR = X currency", we need "1 currency = X INR"
      return 1.0 / rate;
    }

    // Fallback to static rates
    final staticRate = CurrencyConverter.getRate(currency);
    if (staticRate != null) {
      print('📊 Using static rate for $currency: $staticRate');
      return staticRate;
    }

    // Default to 1.0 (assume INR)
    print('⚠️ No rate found for $currency, defaulting to 1.0');
    return 1.0;
  }

  /// Convert amount from one currency to INR
  ///
  /// Example:
  /// ```dart
  /// double inr = await exchangeRateService.convertToINR(100, 'USD');
  /// ```
  Future<double> convertToINR(double amount, String currency) async {
    final rate = await getRate(currency);
    return amount * rate;
  }

  /// Refresh exchange rates from API
  ///
  /// Returns true if successful, false otherwise
  /// Will fallback to static rates if API fails
  Future<bool> refreshRates({bool force = false}) async {
    try {
      // Check if refresh is needed
      if (!force) {
        final cachedRates = await _getRatesFromDb();
        if (cachedRates != null) {
          print('✅ Exchange rates are up to date, skipping refresh');
          return true;
        }
      }

      print('🔄 Refreshing exchange rates from API...');

      // Fetch from API
      final rates = await _fetchRatesFromApi();

      // Save to database
      await _saveRatesToDb(rates);

      print('✅ Exchange rates refreshed successfully');
      return true;
    } catch (e) {
      print('❌ Failed to refresh exchange rates: $e');
      print('📊 Will use static fallback rates');
      return false;
    }
  }

  /// Initialize exchange rates (call on app startup)
  ///
  /// This will:
  /// - Check for cached rates
  /// - Refresh if expired or missing
  /// - Use static rates as fallback
  Future<void> initialize() async {
    print('🚀 Initializing ExchangeRateService...');

    final cachedRates = await _getRatesFromDb();

    if (cachedRates == null) {
      print('📥 No cached rates, attempting to fetch from API...');
      await refreshRates();
    } else {
      final lastUpdate = await getLastUpdateTime();
      print('✅ Exchange rates initialized (last update: $lastUpdate)');
    }
  }

  /// Check if rates need refresh (older than 24 hours)
  Future<bool> needsRefresh() async {
    final lastUpdate = await getLastUpdateTime();
    if (lastUpdate == null) return true;

    final age = DateTime.now().difference(lastUpdate);
    return age > _cacheExpiry;
  }

  /// Get all supported currencies with their rates
  Future<Map<String, double>> getAllRates() async {
    final cachedRates = await _getRatesFromDb();
    if (cachedRates != null) {
      // Convert API rates (1 INR = X currency) to our format (1 currency = X INR)
      return cachedRates.map((currency, rate) => MapEntry(
            currency,
            rate != 0 ? 1.0 / rate : 0.0,
          ));
    }

    // Fallback to static rates
    print('📊 Using static fallback rates');
    final staticRates = <String, double>{};
    for (final currency in CurrencyConverter.getSupportedCurrencies()) {
      final rate = CurrencyConverter.getRate(currency);
      if (rate != null) {
        staticRates[currency] = rate;
      }
    }
    return staticRates;
  }

  /// Clear all cached rates (useful for debugging)
  Future<void> clearCache() async {
    final db = await _db.database;
    await db.delete('exchange_rates');
    print('🗑️ Cleared all cached exchange rates');
  }
}
