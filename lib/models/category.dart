import 'package:flutter/material.dart';

/// Dynamic Category model - backed by database
class Category {
  final String id;
  final String name;
  final bool isDefault;
  final bool isActive;
  final String? iconEmoji;
  final String? colorHex;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.isActive = true,
    this.iconEmoji,
    this.colorHex,
    required this.createdAt,
  });

  /// Create Category from database map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      isDefault: (map['is_default'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      iconEmoji: map['icon_emoji'] as String?,
      colorHex: map['color_hex'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Convert Category to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'icon_emoji': iconEmoji,
      'color_hex': colorHex,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Get Color object from hex string
  Color get color {
    if (colorHex == null || colorHex!.isEmpty) {
      return Colors.grey;
    }
    try {
      return Color(int.parse('FF${colorHex!}', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  /// Get IconData from emoji (fallback to default icon)
  IconData get icon {
    // Map emojis to Flutter icons as fallback
    switch (iconEmoji) {
      case '🍔':
        return Icons.restaurant;
      case '🛒':
        return Icons.shopping_bag;
      case '🚗':
        return Icons.directions_car;
      case '💡':
        return Icons.lightbulb;
      case '🎬':
        return Icons.movie;
      case '🏥':
        return Icons.medical_services;
      case '✈️':
        return Icons.flight;
      case '🥬':
        return Icons.shopping_cart;
      case '📚':
        return Icons.school;
      case '💰':
        return Icons.account_balance_wallet;
      case '📈':
        return Icons.trending_up;
      case '↔️':
        return Icons.swap_horiz;
      default:
        return Icons.category;
    }
  }

  /// Create a copy with updated fields
  Category copyWith({
    String? id,
    String? name,
    bool? isDefault,
    bool? isActive,
    String? iconEmoji,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, isDefault: $isDefault, isActive: $isActive, emoji: $iconEmoji)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Legacy TransactionCategory for backward compatibility
/// This will be deprecated once all screens migrate to dynamic categories
@deprecated
class TransactionCategory {
  final String name;
  final IconData icon;
  final Color color;

  const TransactionCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Legacy Categories class for backward compatibility
/// This will be deprecated once all screens migrate to dynamic categories
@deprecated
class Categories {
  static const foodDining = TransactionCategory(
    name: 'Food & Dining',
    icon: Icons.restaurant,
    color: Colors.orange,
  );

  static const transportation = TransactionCategory(
    name: 'Transportation',
    icon: Icons.directions_car,
    color: Colors.blue,
  );

  static const shopping = TransactionCategory(
    name: 'Shopping',
    icon: Icons.shopping_bag,
    color: Colors.purple,
  );

  static const bills = TransactionCategory(
    name: 'Bills & Utilities',
    icon: Icons.receipt_long,
    color: Colors.red,
  );

  static const entertainment = TransactionCategory(
    name: 'Entertainment',
    icon: Icons.movie,
    color: Colors.pink,
  );

  static const healthcare = TransactionCategory(
    name: 'Healthcare',
    icon: Icons.medical_services,
    color: Colors.green,
  );

  static const income = TransactionCategory(
    name: 'Income',
    icon: Icons.account_balance_wallet,
    color: Colors.teal,
  );

  static const transfer = TransactionCategory(
    name: 'Transfer',
    icon: Icons.swap_horiz,
    color: Colors.indigo,
  );

  static const other = TransactionCategory(
    name: 'Other',
    icon: Icons.more_horiz,
    color: Colors.grey,
  );

  static const uncategorized = TransactionCategory(
    name: 'Uncategorized',
    icon: Icons.help_outline,
    color: Colors.blueGrey,
  );

  static const List<TransactionCategory> all = [
    foodDining,
    transportation,
    shopping,
    bills,
    entertainment,
    healthcare,
    income,
    transfer,
    other,
  ];

  static TransactionCategory getByName(String name) {
    switch (name) {
      case 'Food & Dining':
        return foodDining;
      case 'Transportation':
        return transportation;
      case 'Shopping':
        return shopping;
      case 'Bills & Utilities':
        return bills;
      case 'Entertainment':
        return entertainment;
      case 'Healthcare':
        return healthcare;
      case 'Income':
        return income;
      case 'Transfer':
        return transfer;
      case 'Other':
        return other;
      default:
        return uncategorized;
    }
  }
}
