class RecurringTransaction {
  final String id;
  final String merchant;
  final String category;
  final double averageAmount;
  final int frequency; // Days between transactions
  final DateTime firstOccurrence;
  final DateTime lastOccurrence;
  final DateTime? nextExpectedDate;
  final int occurrenceCount;
  final bool isActive;
  final RecurringFrequency frequencyType;
  final double confidenceScore; // 0.0 to 1.0
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringTransaction({
    required this.id,
    required this.merchant,
    required this.category,
    required this.averageAmount,
    required this.frequency,
    required this.firstOccurrence,
    required this.lastOccurrence,
    this.nextExpectedDate,
    required this.occurrenceCount,
    this.isActive = true,
    required this.frequencyType,
    required this.confidenceScore,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'category': category,
      'average_amount': averageAmount,
      'frequency': frequency,
      'first_occurrence': firstOccurrence.toIso8601String(),
      'last_occurrence': lastOccurrence.toIso8601String(),
      'next_expected_date': nextExpectedDate?.toIso8601String(),
      'occurrence_count': occurrenceCount,
      'is_active': isActive ? 1 : 0,
      'frequency_type': frequencyType.index,
      'confidence_score': confidenceScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as String,
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      averageAmount: (map['average_amount'] as num).toDouble(),
      frequency: map['frequency'] as int,
      firstOccurrence: DateTime.parse(map['first_occurrence'] as String),
      lastOccurrence: DateTime.parse(map['last_occurrence'] as String),
      nextExpectedDate: map['next_expected_date'] != null
          ? DateTime.parse(map['next_expected_date'] as String)
          : null,
      occurrenceCount: map['occurrence_count'] as int,
      isActive: (map['is_active'] as int) == 1,
      frequencyType: RecurringFrequency.values[map['frequency_type'] as int],
      confidenceScore: (map['confidence_score'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  RecurringTransaction copyWith({
    String? id,
    String? merchant,
    String? category,
    double? averageAmount,
    int? frequency,
    DateTime? firstOccurrence,
    DateTime? lastOccurrence,
    DateTime? nextExpectedDate,
    int? occurrenceCount,
    bool? isActive,
    RecurringFrequency? frequencyType,
    double? confidenceScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      averageAmount: averageAmount ?? this.averageAmount,
      frequency: frequency ?? this.frequency,
      firstOccurrence: firstOccurrence ?? this.firstOccurrence,
      lastOccurrence: lastOccurrence ?? this.lastOccurrence,
      nextExpectedDate: nextExpectedDate ?? this.nextExpectedDate,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      isActive: isActive ?? this.isActive,
      frequencyType: frequencyType ?? this.frequencyType,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get frequencyLabel {
    switch (frequencyType) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Bi-weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.quarterly:
        return 'Quarterly';
      case RecurringFrequency.yearly:
        return 'Yearly';
      case RecurringFrequency.custom:
        return 'Every $frequency days';
    }
  }

  bool get isUpcoming {
    if (nextExpectedDate == null) return false;
    final now = DateTime.now();
    final daysUntil = nextExpectedDate!.difference(now).inDays;
    return daysUntil >= 0 && daysUntil <= 7; // Within next 7 days
  }

  bool get isOverdue {
    if (nextExpectedDate == null) return false;
    return DateTime.now().isAfter(nextExpectedDate!);
  }
}

enum RecurringFrequency {
  daily, // ~1 day
  weekly, // ~7 days
  biweekly, // ~14 days
  monthly, // ~30 days
  quarterly, // ~90 days
  yearly, // ~365 days
  custom, // Other
}

RecurringFrequency getFrequencyType(int days) {
  if (days >= 1 && days <= 2) return RecurringFrequency.daily;
  if (days >= 6 && days <= 8) return RecurringFrequency.weekly;
  if (days >= 13 && days <= 16) return RecurringFrequency.biweekly;
  if (days >= 28 && days <= 32) return RecurringFrequency.monthly;
  if (days >= 88 && days <= 92) return RecurringFrequency.quarterly;
  if (days >= 360 && days <= 370) return RecurringFrequency.yearly;
  return RecurringFrequency.custom;
}
