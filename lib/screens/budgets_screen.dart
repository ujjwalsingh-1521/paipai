import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/money.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui.dart';

/// The monthly budget, optional category budgets, and the one alert
/// setting they share.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(budgetProvider).valueOrNull;
    final categories = ref.watch(categoryProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.xxl),
              children: [
                const SectionHeader('Monthly budget'),
                GroupCard(children: [_overallRow(context, data.overallIn(DateTime.now()))]),
                const SizedBox(height: Space.xl),
                const SectionHeader('Category budgets'),
                _categoryBudgets(context, data, categories),
                const SizedBox(height: Space.xl),
                const SectionHeader('Alerts'),
                _AlertSettings(alerts: data.alerts),
              ],
            ),
    );
  }

  Widget _overallRow(BuildContext context, Budget? overall) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
        leading: const _RoundIcon(Icons.savings_rounded),
        title: Text(overall == null ? 'Not set' : '${formatMoney(overall.amount!)} a month',
            style: context.text.titleSmall),
        subtitle: Text(overall == null ? 'Everything you spend in a month' : 'Tap to change or remove',
            style: _muted(context)),
        trailing: overall == null
            ? FilledButton.tonal(onPressed: () => _editOverall(context, null), child: const Text('Set'))
            : Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
        onTap: () => _editOverall(context, overall),
      );

  void _editOverall(BuildContext context, Budget? overall) =>
      showBudgetAmountSheet(context, category: Budget.overall, title: 'Monthly budget', current: overall?.amount);

  Widget _categoryBudgets(BuildContext context, BudgetData data, List<ExpenseCategory> categories) {
    final budgets = data.activeIn(DateTime.now()).where((b) => !b.isOverall).toList();
    final free = categories.where((c) => budgets.every((b) => b.category != c.name)).toList();
    return GroupCard(children: [
      for (final budget in budgets) _categoryRow(context, budget, findCategory(categories, budget.category)),
      if (budgets.isNotEmpty) const Divider(height: 1),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
        leading: const _RoundIcon(Icons.add_rounded),
        title: Text('Add a category budget', style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
        subtitle: budgets.isEmpty ? Text('Only for the categories you want to watch', style: _muted(context)) : null,
        enabled: free.isNotEmpty,
        onTap: () => _addCategoryBudget(context, free),
      ),
    ]);
  }

  Widget _categoryRow(BuildContext context, Budget budget, ExpenseCategory category) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
        leading: CategoryIcon(symbol: category.emoji, color: category.color, size: 40),
        title: Text(category.name, style: context.text.titleSmall),
        subtitle: Text('${formatMoney(budget.amount!)} a month', style: _muted(context)),
        trailing: Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
        onTap: () => showBudgetAmountSheet(context,
            category: budget.category, title: '${budget.category} budget', current: budget.amount),
      );

  Future<void> _addCategoryBudget(BuildContext context, List<ExpenseCategory> free) async {
    final picked = await showModalBottomSheet<ExpenseCategory>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _CategoryPicker(categories: free),
    );
    if (picked == null || !context.mounted) return;
    await showBudgetAmountSheet(context, category: picked.name, title: '${picked.name} budget');
  }

  static TextStyle? _muted(BuildContext context) =>
      context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  const _RoundIcon(this.icon);

  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundColor: context.colors.secondaryContainer,
        foregroundColor: context.colors.onSecondaryContainer,
        child: Icon(icon, size: 20),
      );
}

class _CategoryPicker extends StatelessWidget {
  final List<ExpenseCategory> categories;
  const _CategoryPicker({required this.categories});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Which category?', style: context.text.titleLarge),
        const SizedBox(height: Space.s),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: Space.l), children: [
            for (final category in categories)
              ListTile(
                leading: CategoryIcon(symbol: category.emoji, color: category.color, size: 40),
                title: Text(category.name),
                onTap: () => Navigator.pop(context, category),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// On/off plus the two warning levels; "over budget" always alerts too.
class _AlertSettings extends ConsumerWidget {
  final BudgetAlertSettings alerts;
  const _AlertSettings({required this.alerts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(budgetProvider.notifier);
    void save({bool? enabled, int? first, int? second}) => notifier.setAlerts(BudgetAlertSettings(
          enabled: enabled ?? alerts.enabled,
          first: first ?? alerts.first,
          second: second ?? alerts.second,
        ));
    return GroupCard(children: [
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
        title: Text('Budget alerts', style: context.text.titleSmall),
        subtitle: Text('A notification when a budget gets close, and when it runs out',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        value: alerts.enabled,
        onChanged: (on) => save(enabled: on),
      ),
      if (alerts.enabled) ...[
        const Divider(height: 1),
        _PercentRow(
          label: 'First warning',
          value: alerts.first,
          choices: BudgetAlertSettings.choices.where((p) => p < alerts.second),
          onChanged: (p) => save(first: p),
        ),
        _PercentRow(
          label: 'Second warning',
          value: alerts.second,
          choices: BudgetAlertSettings.choices.where((p) => p > alerts.first),
          onChanged: (p) => save(second: p),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
          child: Text('…and when a budget is over. Each alert comes once a month.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
      ],
    ]);
  }
}

class _PercentRow extends StatelessWidget {
  final String label;
  final int value;
  final Iterable<int> choices;
  final ValueChanged<int> onChanged;

  const _PercentRow({required this.label, required this.value, required this.choices, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = {...choices, value}.toList()..sort();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.l),
      title: Text(label, style: context.text.bodyLarge),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(Corners.medium),
        items: [for (final p in options) DropdownMenuItem(value: p, child: Text('$p% used'))],
        onChanged: (p) {
          if (p != null && p != value) onChanged(p);
        },
      ),
    );
  }
}
