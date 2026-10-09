import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// The big "₹ 0" amount input when adding or editing an entry.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool autofocus;
  const AmountField({
    super.key,
    required this.controller,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.displaySmall?.copyWith(color: colors.onSurface);
    // ₹ sits right next to the number: the field is only as wide as its text.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('₹', style: style?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(width: Space.xs),
        IntrinsicWidth(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: _field(style, colors),
          ),
        ),
      ],
    );
  }

  Widget _field(TextStyle? style, ColorScheme colors) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: style,
      decoration: InputDecoration(
        isCollapsed: true,
        hintText: '0',
        hintStyle: style?.copyWith(
          color: colors.onSurfaceVariant.withAlpha(90),
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
    );
  }
}

/// "Saturday, 03 Oct 2026  ›" row that opens the date picker.
/// [accent] is kept for existing callers; the row uses the theme's primary.
class EntryDateRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  final Color accent;
  const EntryDateRow({
    super.key,
    required this.date,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(Corners.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Corners.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.l,
            vertical: Space.l,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  DateFormat('EEEE, dd MMM yyyy').format(date),
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date picker limited to dates that can have entries (2020 to today).
Future<DateTime?> pickEntryDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

/// "Paid to" (or "Received from") and "Note": two separate fields, so a
/// note never replaces who was paid.
class PayeeAndNoteFields extends StatelessWidget {
  final TextEditingController payee;
  final TextEditingController note;
  final bool income;

  /// False while splitting: each part has its own note then.
  final bool showNote;

  const PayeeAndNoteFields({
    super.key,
    required this.payee,
    required this.note,
    required this.income,
    this.showNote = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: payee,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: income ? 'Received from' : 'Paid to',
            hintText: income
                ? 'e.g. Rahul, Office'
                : 'e.g. Blinkit, Sharma Store',
            prefixIcon: Icon(
              income ? Icons.south_west_rounded : Icons.storefront_rounded,
            ),
          ),
        ),
        if (showNote) ...[
          const SizedBox(height: Space.m),
          TextField(
            controller: note,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Anything to remember (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ],
    );
  }
}

/// Trimmed text, or null when empty.
String? textOrNull(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}
