class SavingsGoal {
  final String id;
  final String name;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String emoji;
  final GoalCategory category;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.description,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    this.emoji = '🎯',
    this.category = GoalCategory.other,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate.toIso8601String(),
      'emoji': emoji,
      'category': category.index,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      targetDate: DateTime.parse(map['target_date'] as String),
      emoji: map['emoji'] as String,
      category: GoalCategory.values[map['category'] as int],
      isCompleted: (map['is_completed'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  SavingsGoal copyWith({
    String? id,
    String? name,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? emoji,
    GoalCategory? category,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get progress {
    if (targetAmount == 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  double get progressPercentage => progress * 100;

  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, targetAmount);

  int get daysRemaining {
    return targetDate.difference(DateTime.now()).inDays;
  }

  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;

  bool get isOnTrack {
    if (isCompleted) return true;
    if (daysRemaining <= 0) return false;

    final daysSinceStart = DateTime.now().difference(createdAt).inDays;
    final totalDays = targetDate.difference(createdAt).inDays;

    if (totalDays == 0) return currentAmount >= targetAmount;

    final expectedProgress = daysSinceStart / totalDays;
    return progress >= expectedProgress * 0.9; // Within 90% of expected progress
  }

  double get monthlyTarget {
    final monthsRemaining = daysRemaining / 30;
    if (monthsRemaining <= 0) return remainingAmount;
    return remainingAmount / monthsRemaining;
  }
}

enum GoalCategory {
  vacation,
  emergency,
  education,
  home,
  car,
  wedding,
  retirement,
  gadget,
  other,
}

extension GoalCategoryExtension on GoalCategory {
  String get label {
    switch (this) {
      case GoalCategory.vacation:
        return 'Vacation';
      case GoalCategory.emergency:
        return 'Emergency Fund';
      case GoalCategory.education:
        return 'Education';
      case GoalCategory.home:
        return 'Home';
      case GoalCategory.car:
        return 'Car';
      case GoalCategory.wedding:
        return 'Wedding';
      case GoalCategory.retirement:
        return 'Retirement';
      case GoalCategory.gadget:
        return 'Gadget';
      case GoalCategory.other:
        return 'Other';
    }
  }

  String get defaultEmoji {
    switch (this) {
      case GoalCategory.vacation:
        return '✈️';
      case GoalCategory.emergency:
        return '🆘';
      case GoalCategory.education:
        return '🎓';
      case GoalCategory.home:
        return '🏠';
      case GoalCategory.car:
        return '🚗';
      case GoalCategory.wedding:
        return '💒';
      case GoalCategory.retirement:
        return '🌴';
      case GoalCategory.gadget:
        return '📱';
      case GoalCategory.other:
        return '🎯';
    }
  }
}
