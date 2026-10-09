import 'package:flutter/material.dart';

import '../models/category_symbol.dart';
import '../theme/app_theme.dart';

/// A category's symbol on a soft circle of its color.
class CategoryIcon extends StatelessWidget {
  final String symbol;
  final Color color;
  final double size;

  const CategoryIcon({super.key, required this.symbol, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final tint = categoryTint(context, color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.background, shape: BoxShape.circle),
      child: CategoryGlyph(symbol: symbol, color: tint.foreground, size: size * 0.5),
    );
  }
}

/// Just the symbol, without the circle (chips, pickers).
class CategoryGlyph extends StatelessWidget {
  final String symbol;
  final Color color;
  final double size;

  const CategoryGlyph({super.key, required this.symbol, required this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final icon = CategorySymbol.iconFor(symbol);
    if (icon != null) return Icon(icon, size: size, color: color);
    // An emoji the user chose: drawn as itself, in its own colors.
    return Text(symbol, style: TextStyle(fontSize: size * 0.95, height: 1.1));
  }
}
