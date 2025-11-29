/// Currency conversion utility
///
/// This file contains exchange rates for converting various currencies to INR (Indian Rupees).
/// Rates are approximate and should be updated periodically for accuracy.
///
/// Last updated: October 2024

class CurrencyConverter {
  // Exchange rates to INR (1 unit of currency = X INR)
  static const Map<String, double> _exchangeRates = {
    // Major currencies
    'USD': 83.12,  // US Dollar
    'EUR': 88.45,  // Euro
    'GBP': 102.34, // British Pound
    'JPY': 0.55,   // Japanese Yen
    'CNY': 11.38,  // Chinese Yuan
    'AUD': 53.67,  // Australian Dollar
    'CAD': 60.89,  // Canadian Dollar
    'CHF': 94.23,  // Swiss Franc
    'SGD': 61.45,  // Singapore Dollar
    'HKD': 10.64,  // Hong Kong Dollar

    // Middle East currencies
    'AED': 22.62,  // UAE Dirham
    'SAR': 22.16,  // Saudi Riyal
    'QAR': 22.84,  // Qatari Riyal
    'KWD': 271.23, // Kuwaiti Dinar
    'OMR': 216.05, // Omani Rial
    'BHD': 220.45, // Bahraini Dinar

    // Asian currencies
    'MYR': 18.67,  // Malaysian Ringgit
    'THB': 2.39,   // Thai Baht
    'IDR': 0.0053, // Indonesian Rupiah
    'PHP': 1.48,   // Philippine Peso
    'KRW': 0.062,  // South Korean Won
    'VND': 0.0034, // Vietnamese Dong

    // Indian Rupee (base currency)
    'INR': 1.0,
    '₹': 1.0,
    'Rs': 1.0,
    'Rs.': 1.0,
  };

  /// Convert amount from given currency to INR
  ///
  /// Example:
  /// ```dart
  /// double inr = CurrencyConverter.toINR(100, 'USD'); // Returns 8312.0
  /// ```
  static double toINR(double amount, String currencyCode) {
    final rate = _exchangeRates[currencyCode.toUpperCase()];
    if (rate == null) {
      // If currency not found, return as-is (assume already in INR)
      return amount;
    }
    return amount * rate;
  }

  /// Convert amount from INR to given currency
  ///
  /// Example:
  /// ```dart
  /// double usd = CurrencyConverter.fromINR(8312, 'USD'); // Returns 100.0
  /// ```
  static double fromINR(double amountInINR, String currencyCode) {
    final rate = _exchangeRates[currencyCode.toUpperCase()];
    if (rate == null || rate == 0) {
      return amountInINR;
    }
    return amountInINR / rate;
  }

  /// Get all supported currency codes
  static List<String> getSupportedCurrencies() {
    return _exchangeRates.keys.toList();
  }

  /// Check if a currency is supported
  static bool isSupported(String currencyCode) {
    return _exchangeRates.containsKey(currencyCode.toUpperCase());
  }

  /// Get exchange rate for a currency (to INR)
  static double? getRate(String currencyCode) {
    return _exchangeRates[currencyCode.toUpperCase()];
  }

  /// Detect currency symbol/code from text and extract amount
  ///
  /// Example:
  /// ```dart
  /// var result = CurrencyConverter.detectAndConvert('$100 payment');
  /// // Returns: {'amount': 8312.0, 'currency': 'USD', 'original': 100.0}
  /// ```
  static Map<String, dynamic>? detectAndConvert(String text) {
    // Common currency symbols and their codes
    final symbolToCurrency = {
      '\$': 'USD',
      '€': 'EUR',
      '£': 'GBP',
      '¥': 'JPY',
      '₹': 'INR',
      'Rs': 'INR',
      'AED': 'AED',
      'SAR': 'SAR',
    };

    for (var entry in symbolToCurrency.entries) {
      if (text.contains(entry.key)) {
        // Try to extract number
        final numberPattern = RegExp(r'[\d,]+\.?\d*');
        final match = numberPattern.firstMatch(text);
        if (match != null) {
          final amountStr = match.group(0)!.replaceAll(',', '');
          final amount = double.tryParse(amountStr);
          if (amount != null) {
            return {
              'amount': toINR(amount, entry.value),
              'currency': entry.value,
              'original': amount,
            };
          }
        }
      }
    }
    return null;
  }

  /// Format amount in INR with proper Indian number system
  ///
  /// Example:
  /// ```dart
  /// String formatted = CurrencyConverter.formatINR(123456.78);
  /// // Returns: "₹1,23,456.78"
  /// ```
  static String formatINR(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final wholePart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    // Indian number system: XX,XX,XXX
    String formatted = '';
    int count = 0;
    for (int i = wholePart.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) {
        formatted = ',$formatted';
      }
      formatted = wholePart[i] + formatted;
      count++;
    }

    return '₹$formatted.$decimalPart';
  }
}
