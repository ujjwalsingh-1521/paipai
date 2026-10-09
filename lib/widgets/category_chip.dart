import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'category_icon.dart';

/// A selectable category or income-source chip, used wherever one is
/// picked. [compact] is the smaller size used inside sheets.
class CategoryChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const CategoryChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = categoryTint(context, color);
    final foreground = selected ? colors.onSecondaryContainer : colors.onSurfaceVariant;
    return Material(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Colors.transparent : colors.outlineVariant),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.m, vertical: compact ? 7 : Space.s + 1),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (emoji == '+')
              Icon(Icons.add_rounded, size: 18, color: colors.primary)
            else
              CategoryGlyph(symbol: emoji, color: selected ? foreground : tint.foreground, size: 18),
            const SizedBox(width: Space.s - 2),
            Text(label, style: context.text.labelLarge?.copyWith(color: foreground)),
          ]),
        ),
      ),
    );
  }
}
