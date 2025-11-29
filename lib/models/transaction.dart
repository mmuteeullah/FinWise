enum TransactionType {
  debit,
  credit,
  unknown,
}

class Transaction {
  final String id;
  final String rawMessage;
  final double? amount;
  final TransactionType type;
  final String merchant;
  final String category;
  final String? accountLastDigits;
  final double? balance;
  final DateTime timestamp;
  final bool isParsed;
  final bool isManuallyEdited;
  final bool autoCategorized;
  final String? categoryRuleId;
  final double categoryConfidence;

  // Hybrid parser fields
  final String? transactionId;
  final double parserConfidence;
  final String? parserType;
  final double? parseTime;
  final String? parsingError;

  // Currency fields
  final String? originalCurrency; // e.g., 'USD', 'EUR', 'AED' (null = INR)
  final double? originalAmount;   // Amount in original currency (null = same as amount)

  Transaction({
    required this.id,
    required this.rawMessage,
    this.amount,
    required this.type,
    required this.merchant,
    this.category = 'Uncategorized',
    this.accountLastDigits,
    this.balance,
    required this.timestamp,
    this.isParsed = false,
    this.isManuallyEdited = false,
    this.autoCategorized = false,
    this.categoryRuleId,
    this.categoryConfidence = 0.0,
    this.transactionId,
    this.parserConfidence = 0.0,
    this.parserType,
    this.parseTime,
    this.parsingError,
    this.originalCurrency,
    this.originalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawMessage': rawMessage,
      'amount': amount,
      'type': type.index,
      'merchant': merchant,
      'category': category,
      'accountLastDigits': accountLastDigits,
      'balance': balance,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isParsed': isParsed ? 1 : 0,
      'isManuallyEdited': isManuallyEdited ? 1 : 0,
      'autoCategorized': autoCategorized ? 1 : 0,
      'categoryRuleId': categoryRuleId,
      'categoryConfidence': categoryConfidence,
      'transactionId': transactionId,
      'parserConfidence': parserConfidence,
      'parserType': parserType,
      'parseTime': parseTime,
      'parsingError': parsingError,
      'originalCurrency': originalCurrency,
      'originalAmount': originalAmount,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      rawMessage: map['rawMessage'] as String,
      amount: map['amount'] as double?,
      type: TransactionType.values[map['type'] as int],
      merchant: map['merchant'] as String,
      category: map['category'] as String? ?? 'Uncategorized',
      accountLastDigits: map['accountLastDigits'] as String?,
      balance: map['balance'] as double?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isParsed: (map['isParsed'] as int) == 1,
      isManuallyEdited: (map['isManuallyEdited'] as int) == 1,
      autoCategorized: (map['autoCategorized'] as int? ?? 0) == 1,
      categoryRuleId: map['categoryRuleId'] as String?,
      categoryConfidence: map['categoryConfidence'] as double? ?? 0.0,
      transactionId: map['transactionId'] as String?,
      parserConfidence: map['parserConfidence'] as double? ?? 0.0,
      parserType: map['parserType'] as String?,
      parseTime: map['parseTime'] as double?,
      parsingError: map['parsingError'] as String?,
      originalCurrency: map['originalCurrency'] as String?,
      originalAmount: map['originalAmount'] as double?,
    );
  }

  Transaction copyWith({
    String? id,
    String? rawMessage,
    double? amount,
    TransactionType? type,
    String? merchant,
    String? category,
    String? accountLastDigits,
    double? balance,
    DateTime? timestamp,
    bool? isParsed,
    bool? isManuallyEdited,
    bool? autoCategorized,
    String? categoryRuleId,
    double? categoryConfidence,
    String? transactionId,
    double? parserConfidence,
    String? parserType,
    double? parseTime,
    String? parsingError,
    String? originalCurrency,
    double? originalAmount,
  }) {
    return Transaction(
      id: id ?? this.id,
      rawMessage: rawMessage ?? this.rawMessage,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      accountLastDigits: accountLastDigits ?? this.accountLastDigits,
      balance: balance ?? this.balance,
      timestamp: timestamp ?? this.timestamp,
      isParsed: isParsed ?? this.isParsed,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
      autoCategorized: autoCategorized ?? this.autoCategorized,
      categoryRuleId: categoryRuleId ?? this.categoryRuleId,
      categoryConfidence: categoryConfidence ?? this.categoryConfidence,
      transactionId: transactionId ?? this.transactionId,
      parserConfidence: parserConfidence ?? this.parserConfidence,
      parserType: parserType ?? this.parserType,
      parseTime: parseTime ?? this.parseTime,
      parsingError: parsingError ?? this.parsingError,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      originalAmount: originalAmount ?? this.originalAmount,
    );
  }
}
