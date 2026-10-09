import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../theme/app_theme.dart';
import '../../utils/analytics.dart';
import '../../utils/budgets.dart';
import '../../utils/money.dart';
import '../budget_widgets.dart';
import '../category_icon.dart';

/// One bar split by category, then every category ranked with its amount
/// and share of the month's spending.
class CategoryBreakdown extends StatelessWidget {
  final List<CategoryTotal> totals;
  final List<ExpenseCategory> categories;

  /// Budgeted categories, by name: their rows add "₹4,200 of ₹6,000" and a bar.
  final Map<String, BudgetStatus> budgets;

  const CategoryBreakdown({super.key, required this.totals, required this.categories, this.budgets = const {}});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ShareBar(totals: totals, categories: categories),
      const SizedBox(height: Space.s),
      for (final total in totals)
        _CategoryLine(total: total, category: findCategory(categories, total.name), budget: budgets[total.name]),
    ]);
  }
}

class _ShareBar extends StatelessWidget {
  final List<CategoryTotal> totals;
  final List<ExpenseCategory> categories;

  const _ShareBar({required this.totals, required this.categories});

  @override
  Widget build(BuildContext context) {
    // Tiny slices still get a sliver so every category shows up.
    return ClipRRect(
      borderRadius: BorderRadius.circular(Corners.small),
      child: SizedBox(
        height: Space.m,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < totals.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              flex: (totals[i].share * 1000).round().clamp(8, 1000),
              child: ColoredBox(color: findCategory(categories, totals[i].name).color),
            ),
          ],
        ]),
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  final CategoryTotal total;
  final ExpenseCategory category;
  final BudgetStatus? budget;

  const _CategoryLine({required this.total, required this.category, this.budget});

  @override
  Widget build(BuildContext context) {
    final percent = (total.share * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(children: [
        CategoryIcon(symbol: category.emoji, color: category.color, size: 36),
        const SizedBox(width: Space.m),
        Expanded(child: _name(context)),
        Text(formatMoney(total.amount), style: context.text.titleSmall),
        SizedBox(
          width: 48,
          child: Text('${percent < 1 ? '<1' : percent}%',
              textAlign: TextAlign.right,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
      ]),
    );
  }

  Widget _name(BuildContext context) {
    final status = budget;
    if (status == null) return Text(category.name, style: context.text.bodyLarge);
    return Padding(
      padding: const EdgeInsets.only(right: Space.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(category.name, style: context.text.bodyLarge),
        Text('${formatMoney(status.spent)} of ${formatMoney(status.limit)}',
            style: context.text.bodySmall?.copyWith(color: budgetColor(context, status.pace))),
        const SizedBox(height: Space.xs),
        BudgetBar(status: status, height: Space.xs),
      ]),
    );
  }
}
