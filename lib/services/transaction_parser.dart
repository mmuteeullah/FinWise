import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../utils/currency_converter.dart';
import 'exchange_rate_service.dart';

class TransactionParser {
  static const _uuid = Uuid();

  /// Parse SMS message and extract transaction details
  static Transaction parse(String smsText) {
    final now = DateTime.now();

    // Try to extract amount
    final amount = _extractAmount(smsText);

    // Determine transaction type
    final type = _extractTransactionType(smsText);

    // Extract merchant/description
    final merchant = _extractMerchant(smsText);

    // Extract account digits
    final accountDigits = _extractAccountDigits(smsText);

    // Extract balance
    final balance = _extractBalance(smsText);

    // Determine if parsing was successful
    final isParsed = amount != null && type != TransactionType.unknown;

    return Transaction(
      id: _uuid.v4(),
      rawMessage: smsText,
      amount: amount,
      type: type,
      merchant: merchant,
      category: 'Uncategorized',
      accountLastDigits: accountDigits,
      balance: balance,
      timestamp: now,
      isParsed: isParsed,
      isManuallyEdited: false,
    );
  }

  /// Parse SMS with currency detection and conversion (async version)
  static Future<Transaction> parseAsync(String smsText) async {
    // First parse with standard method
    final transaction = parse(smsText);

    // Try to detect currency in the SMS text
    final currencyData = CurrencyConverter.detectAndConvert(smsText);

    if (currencyData != null && currencyData['currency'] != 'INR') {
      // Foreign currency detected, convert using live rates
      final String currency = currencyData['currency'];
      final double originalAmount = currencyData['original'];
      final exchangeRateService = ExchangeRateService.instance;
      final convertedAmount = await exchangeRateService.convertToINR(originalAmount, currency);

      print('💱 Regex parser: Detected $originalAmount $currency → ₹$convertedAmount INR');

      // Return transaction with currency fields
      return transaction.copyWith(
        amount: convertedAmount,
        originalCurrency: currency,
        originalAmount: originalAmount,
      );
    }

    // No foreign currency detected, return as is (INR)
    return transaction;
  }

  /// Extract amount from SMS
  static double? _extractAmount(String text) {
    // Patterns for amount extraction
    final patterns = [
      RegExp(r'(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
      RegExp(r'(\d+(?:,\d+)*(?:\.\d{1,2})?)\s*(?:Rs\.?|INR|₹)'),
      RegExp(r'amount\s*(?:of\s*)?(?:Rs\.?|INR|₹)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          return double.tryParse(amountStr);
        }
      }
    }

    return null;
  }

  /// Determine transaction type (debit/credit)
  static TransactionType _extractTransactionType(String text) {
    final lowerText = text.toLowerCase();

    // Credit indicators
    if (lowerText.contains('credited') ||
        lowerText.contains('credit') ||
        lowerText.contains('received') ||
        lowerText.contains('deposited')) {
      return TransactionType.credit;
    }

    // Debit indicators
    if (lowerText.contains('debited') ||
        lowerText.contains('debit') ||
        lowerText.contains('paid') ||
        lowerText.contains('sent') ||
        lowerText.contains('withdrawn') ||
        lowerText.contains('spent') ||
        lowerText.contains('purchase')) {
      return TransactionType.debit;
    }

    return TransactionType.unknown;
  }

  /// Extract merchant name or description
  static String _extractMerchant(String text) {
    // Try to find merchant after common keywords
    final patterns = [
      // After "at", "to", "towards", "for"
      RegExp(r'(?:at|to|towards|for)\s+([A-Z][A-Za-z0-9\s&.-]+?)(?:\s+(?:on|UPI|via|using|dated)|\.|,|$)', caseSensitive: false),
      // After "Info:", "Descr:", "merchant:", "Narration:"
      RegExp(r'(?:Info|Descr|merchant|description|Narration):\s*([A-Za-z0-9\s&.-]+?)(?:\.|,|$)', caseSensitive: false),
      // UPI patterns - more comprehensive
      RegExp(r'UPI[/-]([A-Za-z0-9\s&.-]+?)(?:\s|\.|\||,|$)', caseSensitive: false),
      RegExp(r'(?:UPI|IMPS|NEFT)\s+(?:Ref|ID|Txn)?\s*[:-]?\s*([A-Za-z0-9\s&.-]+?)(?:\s|\.|\||,|$)', caseSensitive: false),
      // Between transaction type and account
      RegExp(r'(?:debited|credited|paid|sent|transferred)(?:\s+from|\s+to)?\s+(?:A/c|account|a/c)?\s*\w+\s+(?:on|at|to|towards|for)\s+([A-Za-z0-9\s&.-]+?)(?:\.|,|$)', caseSensitive: false),
      // EMI and recurring payments
      RegExp(r'(?:EMI|emi|subscription|recurring)\s+(?:for|to|towards)\s+([A-Za-z0-9\s&.-]+?)(?:\.|,|$)', caseSensitive: false),
      // Card transactions
      RegExp(r'(?:Card|card)\s+(?:ending|XX|xx)\s*\d+\s+(?:at|for|to)\s+([A-Za-z0-9\s&.-]+?)(?:\.|,|$)', caseSensitive: false),
      // "Spent at" or "Purchase at"
      RegExp(r'(?:spent|purchase|transaction)\s+at\s+([A-Za-z0-9\s&.-]+?)(?:\.|,|on|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length > 2) {
          // Clean up the merchant name
          return _cleanMerchantName(merchant);
        }
      }
    }

    // If no merchant found, try to extract brand names (expanded list)
    final knownMerchants = [
      // Food & Dining
      'SWIGGY', 'ZOMATO', 'UBEREATS', 'DOMINOS', 'PIZZA HUT', 'KFC',
      'MCDONALDS', 'BURGER KING', 'STARBUCKS', 'CCD', 'CAFE COFFEE DAY',
      'SUBWAY', 'DUNKIN', 'THEOBROMA', 'CHAI POINT', 'BLUE TOKAI',
      'FAASOS', 'BEHROUZ', 'BIRYANI BY KILO',

      // Transportation
      'UBER', 'OLA', 'RAPIDO', 'BOUNCE', 'VOGO', 'YULU',
      'INDIAN OIL', 'BHARAT PETROLEUM', 'HP', 'SHELL',
      'FASTAG', 'PAYTM FASTAG',

      // Shopping
      'AMAZON', 'FLIPKART', 'MYNTRA', 'AJIO', 'MEESHO', 'NYKAA',
      'BIG BASKET', 'GROFERS', 'BLINKIT', 'ZEPTO', 'INSTAMART',
      'RELIANCE DIGITAL', 'CROMA', 'VIJAY SALES',

      // Payments
      'PHONEPE', 'PAYTM', 'GPAY', 'GOOGLE PAY', 'BHIM',
      'MOBIKWIK', 'FREECHARGE', 'AMAZON PAY',

      // Entertainment
      'NETFLIX', 'PRIME VIDEO', 'HOTSTAR', 'DISNEY', 'ZEE5',
      'SPOTIFY', 'YOUTUBE', 'APPLE MUSIC', 'GAANA', 'JIO SAAVN',
      'BOOKMYSHOW', 'PAYTM MOVIES', 'PVR', 'INOX',

      // Bills & Utilities
      'ELECTRICITY', 'BESCOM', 'MSEB', 'TATA POWER',
      'AIRTEL', 'JIO', 'VI', 'VODAFONE', 'IDEA',
      'ACT FIBERNET', 'HATHWAY', 'TATA SKY', 'DISH TV',

      // Healthcare
      'APOLLO', 'PRACTO', 'PHARMEASY', '1MG', 'NETMEDS',
      'MEDPLUS', 'FORTIS', 'MANIPAL',

      // Others
      'INDIAN RAILWAY', 'IRCTC', 'MAKEMYTRIP', 'GOIBIBO',
      'OYO', 'TREEBO', 'FABHOTELS',
    ];

    final upperText = text.toUpperCase();
    for (final merchant in knownMerchants) {
      if (upperText.contains(merchant)) {
        return _cleanMerchantName(merchant);
      }
    }

    return 'Unknown Merchant';
  }

  /// Clean merchant name
  static String _cleanMerchantName(String name) {
    // Remove extra spaces
    name = name.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Capitalize properly
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Extract account last digits
  static String? _extractAccountDigits(String text) {
    // Pattern for account numbers
    final patterns = [
      RegExp(r'A/c\s*(?:XX)?(\d{4})'),
      RegExp(r'account\s*(?:XX)?(\d{4})'),
      RegExp(r'card\s*(?:XX)?(\d{4})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract available balance
  static double? _extractBalance(String text) {
    // Patterns for balance
    final patterns = [
      RegExp(r'(?:Avbl|Available|Avl)\s*(?:bal|balance)?\s*(?:Rs\.?|INR|₹)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
      RegExp(r'balance\s*(?:is\s*)?(?:Rs\.?|INR|₹)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final balanceStr = match.group(1)?.replaceAll(',', '');
        if (balanceStr != null) {
          return double.tryParse(balanceStr);
        }
      }
    }

    return null;
  }
}
