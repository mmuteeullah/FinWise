class CardPreference {
  final String accountLastDigits;
  final bool isVisible;
  final String? cardNickname;
  final String cardType; // 'credit', 'debit', 'prepaid', 'bank_account'
  final String? cardIssuer; // e.g., 'HDFC', 'SBI', 'ICICI'
  final DateTime createdAt;
  final DateTime updatedAt;

  const CardPreference({
    required this.accountLastDigits,
    this.isVisible = true,
    this.cardNickname,
    this.cardType = 'credit',
    this.cardIssuer,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'account_last_digits': accountLastDigits,
      'is_visible': isVisible ? 1 : 0,
      'card_nickname': cardNickname,
      'card_type': cardType,
      'card_issuer': cardIssuer,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CardPreference.fromMap(Map<String, dynamic> map) {
    return CardPreference(
      accountLastDigits: map['account_last_digits'] as String,
      isVisible: (map['is_visible'] as int) == 1,
      cardNickname: map['card_nickname'] as String?,
      cardType: (map['card_type'] as String?) ?? 'credit',
      cardIssuer: map['card_issuer'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  CardPreference copyWith({
    String? accountLastDigits,
    bool? isVisible,
    String? cardNickname,
    String? cardType,
    String? cardIssuer,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardPreference(
      accountLastDigits: accountLastDigits ?? this.accountLastDigits,
      isVisible: isVisible ?? this.isVisible,
      cardNickname: cardNickname ?? this.cardNickname,
      cardType: cardType ?? this.cardType,
      cardIssuer: cardIssuer ?? this.cardIssuer,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CardPreference(accountLastDigits: $accountLastDigits, isVisible: $isVisible, '
        'nickname: $cardNickname, type: $cardType, issuer: $cardIssuer)';
  }

  /// Helper method to get display name
  String get displayName {
    if (cardNickname != null && cardNickname!.isNotEmpty) {
      return cardNickname!;
    }

    if (cardIssuer != null && cardIssuer!.isNotEmpty) {
      return '$cardIssuer ••$accountLastDigits';
    }

    return '••••$accountLastDigits';
  }

  /// Helper method to get card type display name
  String get cardTypeDisplay {
    switch (cardType.toLowerCase()) {
      case 'credit':
        return 'Credit Card';
      case 'debit':
        return 'Debit Card';
      case 'prepaid':
        return 'Prepaid Card';
      case 'bank_account':
        return 'Bank Account';
      default:
        return cardType;
    }
  }
}
