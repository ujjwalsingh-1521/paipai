import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/category_symbol.dart';
import '../theme/app_theme.dart';
import 'category_icon.dart';

/// Create or edit a category / income source: name, symbol and colour.
/// [nameError] returns a message (e.g. "Food" already exists) to show
/// instead of saving. [accentColor] is kept for existing callers; the sheet
/// now takes its colors from the theme.
Future<void> showCategorySheet(
  BuildContext context, {
  required String title,
  required String buttonLabel,
  required String? Function(String name) nameError,
  required Future<void> Function(ExpenseCategory category) onSaved,
  ExpenseCategory? initial,
  Set<int> usedColors = const {},
  Color? accentColor,
  String hint = 'Enter name',
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategorySheet(
        title: title,
        buttonLabel: buttonLabel,
        nameError: nameError,
        onSaved: onSaved,
        initial: initial,
        usedColors: usedColors,
        hint: hint,
      ),
    );

class _CategorySheet extends StatefulWidget {
  final String title;
  final String buttonLabel;
  final String? Function(String name) nameError;
  final Future<void> Function(ExpenseCategory category) onSaved;
  final ExpenseCategory? initial;
  final Set<int> usedColors;
  final String hint;

  const _CategorySheet({
    required this.title,
    required this.buttonLabel,
    required this.nameError,
    required this.onSaved,
    required this.initial,
    required this.usedColors,
    required this.hint,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name;
  late String _emoji;
  late int _color;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _emoji = widget.initial?.emoji ?? CategorySymbol.fallback;
    _color = widget.initial?.colorValue ?? _firstUnusedColor();
  }

  int _firstUnusedColor() => availableColors
      .firstWhere((c) => !widget.usedColors.contains(c), orElse: () => availableColors[0]);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = widget.nameError(_name.text);
    if (error != null) return setState(() => _error = error);
    setState(() => _saving = true);
    try {
      await widget.onSaved(
          ExpenseCategory(name: _name.text.trim(), emoji: _emoji, colorValue: _color));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // e.g. the database rejected a duplicate the check missed.
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Space.xl, 0, Space.xl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: context.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Space.l),
          Center(child: CategoryIcon(symbol: _emoji, color: Color(_color), size: 64)),
          const SizedBox(height: Space.l),
          TextField(
            controller: _name,
            decoration: InputDecoration(
                labelText: 'Name', hintText: widget.hint, errorText: _error),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _error == null ? null : setState(() => _error = null),
          ),
          const SizedBox(height: Space.l),
          const _Label('Icon'),
          _SymbolGrid(selected: _emoji, onPick: (e) => setState(() => _emoji = e)),
          const SizedBox(height: Space.m),
          _EmojiField(selected: _emoji, onPick: (e) => setState(() => _emoji = e)),
          const SizedBox(height: Space.l),
          const _Label('Color'),
          _ColorRow(selected: _color, onPick: (c) => setState(() => _color = c)),
          const SizedBox(height: Space.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: Text(text, style: context.text.titleSmall),
      );
}

/// Every icon, in groups, inside a fixed-height scroll box (so the color
/// row and Save stay close). Opens scrolled to the current icon.
class _SymbolGrid extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const _SymbolGrid({required this.selected, required this.onPick});

  @override
  State<_SymbolGrid> createState() => _SymbolGridState();
}

class _SymbolGridState extends State<_SymbolGrid> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.4);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 248,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Corners.medium),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final group in CategorySymbol.groups) ...[
            Padding(
              padding: const EdgeInsets.only(left: Space.xs, bottom: Space.xs),
              child: Text(group.title,
                  style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
            Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
              for (final name in group.icons.keys) _cell(context, CategorySymbol.icon(name)),
            ]),
            const SizedBox(height: Space.m),
          ],
        ]),
      ),
    );
  }

  Widget _cell(BuildContext context, String symbol) {
    final colors = context.colors;
    final isSelected = symbol == widget.selected;
    return Material(
      key: isSelected ? _selectedKey : null,
      color: isSelected ? colors.secondaryContainer : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => widget.onPick(symbol),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: CategoryGlyph(
              symbol: symbol,
              color: isSelected ? colors.onSecondaryContainer : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Or use an emoji: [ 🏏 ]". Typing replaces whatever was there, so the
/// field always holds one emoji (or other single character).
class _EmojiField extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const _EmojiField({required this.selected, required this.onPick});

  @override
  State<_EmojiField> createState() => _EmojiFieldState();
}

class _EmojiFieldState extends State<_EmojiField> {
  late final _controller = TextEditingController(
      text: CategorySymbol.iconFor(widget.selected) == null ? widget.selected : '');

  @override
  void didUpdateWidget(_EmojiField old) {
    super.didUpdateWidget(old);
    // An icon was picked: the emoji no longer applies.
    if (CategorySymbol.iconFor(widget.selected) != null && _controller.text.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    if (text.isEmpty) return;
    final last = text.characters.last;
    if (last != text) {
      _controller.value = TextEditingValue(
          text: last, selection: TextSelection.collapsed(offset: last.length));
    }
    widget.onPick(last);
  }

  @override
  Widget build(BuildContext context) {
    final inUse = CategorySymbol.iconFor(widget.selected) == null;
    return Row(children: [
      Expanded(
        child: Text('Or type any emoji here',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
      ),
      SizedBox(
        width: 72,
        child: TextField(
          controller: _controller,
          onChanged: _changed,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall,
          decoration: InputDecoration(
            // Not an emoji: emoji ignore hint colors and would look picked.
            hintText: '+',
            contentPadding: const EdgeInsets.symmetric(vertical: Space.s),
            enabledBorder: inUse
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Corners.medium),
                    borderSide: BorderSide(color: context.colors.primary, width: 2))
                : null,
          ),
        ),
      ),
    ]);
  }
}

class _ColorRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPick;
  const _ColorRow({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [for (final c in availableColors) _swatch(context, c)],
    );
  }

  Widget _swatch(BuildContext context, int value) {
    final color = Color(value);
    final isSelected = value == selected;
    // Dark check on light swatches (yellows), white on the rest.
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: () => onPick(value),
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: isSelected ? context.colors.onSurface : Colors.transparent, width: 2),
        ),
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: isSelected ? Icon(Icons.check_rounded, color: checkColor, size: 18) : null,
        ),
      ),
    );
  }
}
