import 'package:flutter/material.dart';

class ExpenseCategory {
  final int? id;
  final String name;

  /// `icon:<name>` or an emoji (see CategorySymbol); the column is still
  /// called `emoji` from when only emoji existed.
  final String emoji;
  final int colorValue;
  final bool isDefault;

  ExpenseCategory({
    this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    this.isDefault = false,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'color': colorValue,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      colorValue: map['color'] as int,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}

/// Seeded on first run (and added on upgrade when the name is free).
/// Symbols are `icon:<name>` (see CategorySymbol).
const List<Map<String, dynamic>> defaultCategoryData = [
  {'name': 'Food', 'emoji': 'icon:restaurant', 'color': 0xFFFF6B6B},
  {'name': 'Groceries', 'emoji': 'icon:local_grocery_store', 'color': 0xFF2ECC71},
  {'name': 'Transport', 'emoji': 'icon:commute', 'color': 0xFF4ECDC4},
  {'name': 'Shopping', 'emoji': 'icon:shopping_bag', 'color': 0xFFFFBE0B},
  {'name': 'Bills', 'emoji': 'icon:receipt_long', 'color': 0xFF845EC2},
  {'name': 'Entertainment', 'emoji': 'icon:movie', 'color': 0xFFFF6F91},
  {'name': 'Health', 'emoji': 'icon:medical_services', 'color': 0xFF00C9A7},
  {'name': 'Education', 'emoji': 'icon:school', 'color': 0xFF4D8076},
  {'name': 'Travel', 'emoji': 'icon:luggage', 'color': 0xFF3B86FF},
  {'name': 'Other', 'emoji': 'icon:more_horiz', 'color': 0xFF9B9B9B},
];

const List<int> availableColors = [
  0xFFFF6B6B, 0xFFFF8E53, 0xFFFFBE0B, 0xFFFED766,
  0xFF00C9A7, 0xFF4ECDC4, 0xFF3B86FF, 0xFF667EEA,
  0xFF845EC2, 0xFFFF6F91, 0xFFE74C3C, 0xFF9B59B6,
  0xFF2ECC71, 0xFF1ABC9C, 0xFFE91E63, 0xFF4D8076,
];
