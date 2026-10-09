import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/income_source_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/category_sheet.dart';
import '../widgets/ui.dart';

/// Room under the list so the last row can scroll clear of the "New" button.
const _fabClearance = 96.0;

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Expense categories'), Tab(text: 'Income sources')],
          ),
        ),
        body: const TabBarView(children: [
          _CategoryTab(income: false),
          _CategoryTab(income: true),
        ]),
      ),
    );
  }
}

/// What differs between the expense-category and income-source tabs.
class _Kind {
  final String noun; // "Category" / "Source"
  final String entry; // what moves when one is deleted
  final String entries;
  final Color accent;
  final List<ExpenseCategory> items;
  final String? Function(String name, {int? exceptId}) nameError;
  final Future<void> Function(ExpenseCategory) add;
  final Future<void> Function(ExpenseCategory, String oldName) update;
  final Future<void> Function(ExpenseCategory, String moveTo) delete;
  final Future<int> Function(String name) usageCount;

  const _Kind({
    required this.noun,
    required this.entry,
    required this.entries,
    required this.accent,
    required this.items,
    required this.nameError,
    required this.add,
    required this.update,
    required this.delete,
    required this.usageCount,
  });

  factory _Kind.of(BuildContext context, WidgetRef ref, {required bool income}) {
    if (income) {
      final n = ref.read(incomeSourceProvider.notifier);
      return _Kind(
        noun: 'Source',
        entry: 'income entry',
        entries: 'income entries',
        accent: context.money.income,
        items: ref.watch(incomeSourceProvider).valueOrNull ?? [],
        nameError: n.nameError,
        add: n.addSource,
        update: n.updateSource,
        delete: n.deleteSource,
        usageCount: n.usageCount,
      );
    }
    final n = ref.read(categoryProvider.notifier);
    return _Kind(
      noun: 'Category',
      entry: 'expense',
      entries: 'expenses',
      accent: context.colors.primary,
      items: ref.watch(categoryProvider).valueOrNull ?? [],
      nameError: n.nameError,
      add: n.addCategory,
      update: n.updateCategory,
      delete: n.deleteCategory,
      usageCount: n.usageCount,
    );
  }
}

class _CategoryTab extends ConsumerWidget {
  final bool income;
  const _CategoryTab({required this.income});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = _Kind.of(context, ref, income: income);
    // Defaults first, then the user's own.
    final sorted = [
      ...kind.items.where((c) => c.isDefault),
      ...kind.items.where((c) => !c.isDefault),
    ];
    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, _fabClearance),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.s, Space.xs, Space.m),
            child: Text('Tap one to edit. Custom ones can also be deleted.',
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          if (sorted.isNotEmpty) _list(context, kind, sorted),
        ],
      ),
      Positioned(
        bottom: Space.l,
        right: Space.l,
        child: FloatingActionButton.extended(
          heroTag: income ? 'add_src' : 'add_cat',
          onPressed: () => _add(context, kind),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New'),
        ),
      ),
    ]);
  }

  Widget _list(BuildContext context, _Kind kind, List<ExpenseCategory> items) => GroupCard(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: Space.l, endIndent: Space.l),
            _CategoryRow(
              item: items[i],
              onTap: () => _edit(context, kind, items[i]),
              onDelete: items[i].isDefault ? null : () => _confirmDelete(context, kind, items[i]),
            ),
          ],
        ],
      );

  void _add(BuildContext context, _Kind kind) => showCategorySheet(
        context,
        title: 'Create ${kind.noun}',
        buttonLabel: 'Create',
        accentColor: kind.accent,
        usedColors: {...kind.items.map((c) => c.colorValue)},
        nameError: (name) => kind.nameError(name),
        onSaved: kind.add,
      );

  void _edit(BuildContext context, _Kind kind, ExpenseCategory existing) => showCategorySheet(
        context,
        title: 'Edit ${kind.noun}',
        buttonLabel: 'Save',
        accentColor: kind.accent,
        initial: existing,
        nameError: (name) => kind.nameError(name, exceptId: existing.id),
        onSaved: (updated) => kind.update(
          ExpenseCategory(
            id: existing.id,
            name: updated.name,
            emoji: updated.emoji,
            colorValue: updated.colorValue,
            isDefault: existing.isDefault,
          ),
          existing.name,
        ),
      );

  Future<void> _confirmDelete(BuildContext context, _Kind kind, ExpenseCategory item) async {
    final used = await kind.usageCount(item.name);
    if (!context.mounted) return;
    final others = kind.items.where((c) => c.id != item.id).map((c) => c.name).toList();
    final moveTo = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteDialog(
          item: item, used: used, entries: used == 1 ? kind.entry : kind.entries, options: others),
    );
    if (moveTo != null) await kind.delete(item, moveTo);
  }
}

/// One category: tap to edit; custom ones can be deleted (button or long press).
class _CategoryRow extends StatelessWidget {
  final ExpenseCategory item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _CategoryRow({required this.item, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CategoryIcon(symbol: item.emoji, color: item.color),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: item.isDefault ? null : const Text('Custom'),
      trailing: onDelete == null
          ? Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant)
          : IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            ),
      onTap: onTap,
      onLongPress: onDelete,
    );
  }
}

/// "Delete Games? Its 12 expenses will move to: [Other ▾]". Returns the
/// category to move to, or null if cancelled.
class _DeleteDialog extends StatefulWidget {
  final ExpenseCategory item;
  final int used;
  final String entries;
  final List<String> options;
  const _DeleteDialog(
      {required this.item, required this.used, required this.entries, required this.options});

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  late String _moveTo =
      widget.options.contains('Other') ? 'Other' : widget.options.first;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text('Delete "${widget.item.name}"?'),
      content: widget.used == 0 ? const Text('Nothing uses it yet.') : _moveToPicker(),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _moveTo),
          style: FilledButton.styleFrom(
              backgroundColor: colors.error, foregroundColor: colors.onError),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _moveToPicker() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Its ${widget.used} ${widget.entries} will move to:'),
          const SizedBox(height: Space.s),
          DropdownButton<String>(
            value: _moveTo,
            isExpanded: true,
            items: [for (final o in widget.options) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => setState(() => _moveTo = v ?? _moveTo),
          ),
        ],
      );
}
