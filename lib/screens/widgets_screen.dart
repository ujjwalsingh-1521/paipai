import 'package:flutter/material.dart';

import '../services/capture/capture_channel.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Settings → Home-screen widgets: what each one does, with a button that
/// asks the launcher to add it (or how to add it by hand).
class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  late final Future<bool> _canPin = CaptureChannel.canPinWidgets();

  static const _widgets = [
    (kind: 'label', icon: Icons.label_important_rounded, title: 'Label payments',
        text: 'The next payment without a category, with its two usual categories and More.'),
    (kind: 'pace', icon: Icons.show_chart_rounded, title: 'This month so far',
        text: 'Spending this month against last month. Tap it for Insights.'),
    (kind: 'categories', icon: Icons.donut_small_rounded, title: 'Where it went',
        text: 'This month by category, with amounts and shares. Tap it for Insights.'),
    (kind: 'add', icon: Icons.add_rounded, title: 'Quick add',
        text: 'Add an expense or income without opening the app.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home-screen widgets')),
      body: FutureBuilder(
        future: _canPin,
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.xxl),
          children: [
            GroupCard(children: [
              for (var i = 0; i < _widgets.length; i++) ...[
                if (i > 0) const Divider(indent: 72, endIndent: Space.l),
                _row(_widgets[i], canPin: snapshot.data ?? false),
              ],
            ]),
            const SizedBox(height: Space.l),
            Text(
              'You can also add them yourself: touch and hold an empty spot on your home '
              'screen, tap Widgets, and find PaiPai.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(({String kind, IconData icon, String title, String text}) item, {required bool canPin}) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.s, Space.s),
      leading: CircleAvatar(
        backgroundColor: context.colors.secondaryContainer,
        foregroundColor: context.colors.onSecondaryContainer,
        child: Icon(item.icon, size: 20),
      ),
      title: Text(item.title, style: context.text.titleSmall),
      subtitle: Text(item.text,
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
      trailing: canPin
          ? FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => CaptureChannel.pinWidget(item.kind),
              child: const Text('Add'),
            )
          : null,
    );
  }
}
