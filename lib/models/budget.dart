class Budget {
  final String id;
  final String category;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool rolloverEnabled;
  final double rolledOverAmount;

  const Budget({
    required this.id,
    required this.category,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.rolloverEnabled = false,
    this.rolledOverAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'rollover_enabled': rolloverEnabled ? 1 : 0,
      'rolled_over_amount': rolledOverAmount,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      rolloverEnabled: (map['rollover_enabled'] as int?) == 1,
      rolledOverAmount: ((map['rolled_over_amount'] as num?) ?? 0.0).toDouble(),
    );
  }

  Budget copyWith({
    String? id,
    String? category,
    double? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? rolloverEnabled,
    double? rolledOverAmount,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rolloverEnabled: rolloverEnabled ?? this.rolloverEnabled,
      rolledOverAmount: rolledOverAmount ?? this.rolledOverAmount,
    );
  }

  /// Total available budget (base amount + rolled over amount)
  double get totalBudget => amount + rolledOverAmount;
}
