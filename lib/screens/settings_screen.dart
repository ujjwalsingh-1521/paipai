import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/balance_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/balance_sheet.dart';
import '../widgets/ui.dart';
import 'auto_capture_screen.dart';
import 'backup_screen.dart';
import 'budgets_screen.dart';
import 'manage_categories_screen.dart';
import 'widgets_screen.dart';

/// Everything that isn't day-to-day: balance, categories, capture, backup,
/// appearance.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.xxl),
        children: [
          GroupCard(children: [
            _Item(
              icon: Icons.account_balance_rounded,
              title: 'Bank balance',
              subtitle: _balanceText(ref),
              onTap: () => showBalanceSheet(context),
            ),
            const _Divider(),
            _Item(
              icon: Icons.category_rounded,
              title: 'Categories',
              subtitle: 'Expense categories and income sources',
              onTap: () => _open(context, const ManageCategoriesScreen()),
            ),
            const _Divider(),
            _Item(
              icon: Icons.savings_rounded,
              title: 'Budgets',
              subtitle: _budgetText(ref),
              onTap: () => _open(context, const BudgetsScreen()),
            ),
          ]),
          const SizedBox(height: Space.l),
          GroupCard(children: [
            _Item(
              icon: Icons.notifications_active_rounded,
              title: 'Payment auto-capture',
              subtitle: 'Pick up payments from bank SMS',
              onTap: () => _open(context, const AutoCaptureScreen()),
            ),
            const _Divider(),
            _Item(
              icon: Icons.widgets_rounded,
              title: 'Home-screen widgets',
              subtitle: 'Label payments, this month, categories, quick add',
              onTap: () => _open(context, const WidgetsScreen()),
            ),
            const _Divider(),
            _Item(
              icon: Icons.cloud_upload_rounded,
              title: 'Backup & restore',
              subtitle: 'Daily backup to Downloads, or a file you keep',
              onTap: () => _open(context, const BackupScreen()),
            ),
          ]),
          const SizedBox(height: Space.xl),
          const SectionHeader('Appearance'),
          const _ThemePicker(),
        ],
      ),
    );
  }

  static String _budgetText(WidgetRef ref) {
    final active = ref.watch(budgetProvider).valueOrNull?.activeIn(DateTime.now()) ?? [];
    if (active.isEmpty) return 'Set a monthly limit and get alerts';
    final overall = active.where((b) => b.isOverall).firstOrNull;
    final categories = active.length - (overall == null ? 0 : 1);
    return [
      if (overall != null) '${formatMoney(overall.amount!)} a month',
      if (categories > 0) categories == 1 ? '1 category' : '$categories categories',
    ].join(' · ');
  }

  static String _balanceText(WidgetRef ref) {
    final start = ref.watch(balanceStartProvider).valueOrNull;
    if (start == null) return 'Not set. Tap to set it';
    final balance = ref.watch(balanceProvider).valueOrNull ??
        start.currentBalance(
          ref.watch(expenseProvider).valueOrNull ?? [],
          ref.watch(incomeProvider).valueOrNull ?? [],
        );
    return '${formatMoney(balance)} · tap to correct';
  }

  static void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Item({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
      leading: CircleAvatar(
        backgroundColor: context.colors.secondaryContainer,
        foregroundColor: context.colors.onSecondaryContainer,
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: context.text.titleSmall),
      subtitle: Text(subtitle, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(indent: 72, endIndent: Space.l);
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('Phone'), icon: Icon(Icons.brightness_auto_rounded)),
        ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
        ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
      ],
      selected: {ref.watch(themeModeProvider)},
      onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
    );
  }
}
