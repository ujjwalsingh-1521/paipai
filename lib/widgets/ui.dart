import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Recent ........ See all" above a group of content.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Space.xs, bottom: Space.s),
      child: Row(children: [
        Expanded(child: Text(title, style: context.text.titleMedium)),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ]),
    );
  }
}

/// A rounded tonal block holding related rows (Material 3 list group).
class GroupCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const GroupCard({super.key, required this.children, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// Friendly message where a list or chart has nothing to show yet.
class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyNote({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(children: [
        Icon(icon, size: 40, color: context.colors.primary),
        const SizedBox(height: Space.m),
        Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: Space.xs),
        Text(message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
      ]),
    );
  }
}
