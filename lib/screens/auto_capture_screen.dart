import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pending_transaction_provider.dart';
import '../services/capture/capture_channel.dart';
import '../services/capture/capture_service.dart';
import '../services/capture/parsed_payment.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Setup for automatic payment capture: two permissions, a test, and the
/// merchants PaiPai has learned.
class AutoCaptureScreen extends ConsumerStatefulWidget {
  const AutoCaptureScreen({super.key});

  @override
  ConsumerState<AutoCaptureScreen> createState() => _AutoCaptureScreenState();
}

class _AutoCaptureScreenState extends ConsumerState<AutoCaptureScreen>
    with WidgetsBindingObserver {
  bool? _hasAccess;
  bool? _canNotify;
  CaptureHealth? _health;
  SmsStatus? _sms;
  // Android didn't show the SMS prompt: explain the App info fix.
  bool _smsBlocked = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The user comes back from Android settings: re-check.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStatus();
  }

  Future<void> _loadStatus() async {
    final access = await CaptureChannel.hasNotificationAccess();
    final notify = await CaptureChannel.canPostNotifications();
    final health = await CaptureChannel.health();
    final sms = await CaptureChannel.smsStatus();
    if (!mounted) return;
    setState(() {
      _hasAccess = access;
      _canNotify = notify;
      _health = health;
      _sms = sms;
      if (sms.granted) _smsBlocked = false;
    });
  }

  Future<void> _allowSms() async {
    final answer = await CaptureChannel.requestSmsPermission();
    if (!mounted) return;
    setState(() => _smsBlocked = answer == 'blocked');
    await _loadStatus();
  }

  Future<void> _setAppAlerts(bool enabled) async {
    await CaptureChannel.setAppAlerts(enabled);
    await _loadStatus();
  }

  /// "Bring in older payments": the user picks how far back.
  Future<void> _importPast() async {
    final now = DateTime.now();
    final from = await showDatePicker(
      context: context,
      helpText: 'Bring in payments since',
      initialDate: DateTime(now.year, now.month),
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
    );
    if (from == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final found = await CaptureChannel.importSms(from);
      await ref.read(pendingTransactionProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (found) {
          0 => 'No new payments found since then.',
          1 => 'Found 1 new payment. It waits on Home to be labelled.',
          _ => 'Found $found new payments. They wait on Home to be labelled.',
        }),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Couldn't read older SMS: $error")));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _sendTestPayment() async {
    final ref12 = (100000000000 + Random().nextInt(899999999)).toString();
    await CaptureService(alerts: NativeCaptureAlerts()).handleNotification(
      NotificationInput(
        app: 'paipai.test',
        title: 'PaiPai test',
        text: 'Rs 1.00 debited from A/c XX0000 to PaiPai Test Shop. UPI Ref $ref12',
        postedAt: DateTime.now(),
        messageId: 'test:$ref12',
      ),
    );
    await ref.read(pendingTransactionProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Test payment of ₹1 sent. Check your notifications.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final smsOn = _sms?.granted == true;
    // Without SMS, notification access is how payments are found.
    final ready = (smsOn || _hasAccess == true) && _canNotify == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-capture payments')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.xxl),
        children: [
          _StatusBanner(ready: ready, loading: _hasAccess == null || _sms == null),
          const SizedBox(height: Space.l),
          _smsStep(smsOn),
          const SizedBox(height: Space.m),
          _notifyStep(),
          const SizedBox(height: Space.m),
          if (smsOn) ...[_importCard(), const SizedBox(height: Space.m)],
          _appAlertsCard(smsOn),
          const SizedBox(height: Space.m),
          // Hidden SMS texts only matter while SMS come through notifications.
          if (!smsOn && _hasAccess == true && _health?.affected == true) ...[
            _HiddenMessagesStep(health: _health!),
            const SizedBox(height: Space.m),
          ],
          _testCard(ready),
          const SizedBox(height: Space.xl),
          const _HowSuggestionsWork(),
        ],
      ),
    );
  }

  Widget _smsStep(bool smsOn) => _StepCard(
        number: 1,
        title: 'Read bank SMS',
        description: 'Every payment, from any bank or UPI app, brings a bank SMS. '
            'PaiPai reads only messages from businesses that mention money (never '
            'personal chats or ads), also ones that came while your phone was off. '
            'Nothing leaves your phone.',
        done: smsOn,
        actionLabel: 'Allow',
        onAction: _allowSms,
        help: smsOn || !_smsBlocked ? null : const _RestrictedSettingsHelp(sms: true),
      );

  Widget _importCard() => GroupCard(
        padding: const EdgeInsets.all(Space.l),
        children: [
          Row(children: [
            Icon(Icons.history_rounded, color: context.colors.primary),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(
                  'Bring in payments from older SMS, from a date you choose. Ones from '
                  "before you set your bank balance won't change it.",
                  style: context.text.bodyMedium),
            ),
            const SizedBox(width: Space.s),
            _importing
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
                : FilledButton.tonal(onPressed: _importPast, child: const Text('Choose')),
          ]),
        ],
      );

  /// Optional with SMS on; the only way to capture without it.
  Widget _appAlertsCard(bool smsOn) {
    final access = _hasAccess == true;
    if (!smsOn) {
      return _StepCard(
        number: 3,
        title: 'Or read payment notifications',
        description: 'Without SMS, PaiPai can read notifications instead: bank SMS '
            '(through your messages app), UPI apps and bank emails. Payments can be '
            'missed this way (phone off, notification cleared).',
        done: access,
        actionLabel: 'Allow',
        onAction: CaptureChannel.openNotificationAccessSettings,
        help: access ? null : const _RestrictedSettingsHelp(),
      );
    }
    final on = _sms!.appAlerts;
    return GroupCard(
      padding: const EdgeInsets.all(Space.l),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Also read payment app notifications', style: context.text.titleMedium),
          subtitle: const _MutedText('Optional. For payments some banks send no SMS for '
              '(UPI Lite, wallets, small UPI payments), and clearer shop names.'),
          value: on,
          onChanged: _setAppAlerts,
        ),
        if (on && !access) ...[
          const SizedBox(height: Space.s),
          const Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: CaptureChannel.openNotificationAccessSettings,
              child: Text('Allow notification access'),
            ),
          ),
          const SizedBox(height: Space.m),
          const _RestrictedSettingsHelp(),
        ],
      ],
    );
  }

  Widget _notifyStep() => _StepCard(
        number: 2,
        title: 'Show payment alerts',
        description: 'So you can pick a category right from the notification, '
            'even when the phone is locked.',
        done: _canNotify == true,
        actionLabel: 'Allow',
        onAction: CaptureChannel.requestPostNotifications,
      );

  Widget _testCard(bool ready) => GroupCard(
        padding: const EdgeInsets.all(Space.l),
        children: [
          Row(children: [
            Icon(Icons.science_rounded, color: context.colors.primary),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text('Send a test payment of ₹1 to see how an alert looks.',
                  style: context.text.bodyMedium),
            ),
            const SizedBox(width: Space.s),
            FilledButton.tonal(
                onPressed: ready ? _sendTestPayment : null, child: const Text('Test')),
          ]),
        ],
      );
}

/// Android 15+ can hide bank SMS from PaiPai (it mistakes them for
/// one-time codes). Optional step with the two known fixes.
class _HiddenMessagesStep extends StatelessWidget {
  static const _adbCommand = 'adb shell cmd appops set --user 0 '
      'com.expense.expense_tracker RECEIVE_SENSITIVE_NOTIFICATIONS allow';

  final CaptureHealth health;
  const _HiddenMessagesStep({required this.health});

  @override
  Widget build(BuildContext context) {
    final done = health.canReadSensitive;
    return GroupCard(
      padding: const EdgeInsets.all(Space.l),
      children: [
        _StepTitle(number: 4, done: done, title: 'Let PaiPai read every bank SMS'),
        const SizedBox(height: Space.s),
        _MutedText(_summary()),
        if (!done) ...[const SizedBox(height: Space.l), ..._fixes(context)],
      ],
    );
  }

  String _summary() {
    if (health.canReadSensitive) return 'Done. PaiPai can read all payment messages.';
    const why = 'Android 15+ hides messages it thinks contain login codes, and '
        'sometimes bank SMS too.';
    if (health.needsFix) {
      return '$why It hid ${health.hiddenCount} message(s) from PaiPai this week '
          '(some may be real login codes). Use one fix below once so payments '
          "aren't missed.";
    }
    return "$why If an SMS payment doesn't show up, use one fix below once.";
  }

  List<Widget> _fixes(BuildContext context) => [
        Text('Fix A, on the phone', style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        const _MutedText('Settings → Notifications → turn off "Enhanced notifications" '
            '(on some phones: "Suggest actions and replies").'),
        const Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: CaptureChannel.openNotificationSettings,
            child: Text('Open notification settings'),
          ),
        ),
        const SizedBox(height: Space.s),
        Text('Fix B, with a computer', style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        const _MutedText("Connect the phone by USB once and run this. Then turn PaiPai's "
            'notification access off and on again:'),
        const SizedBox(height: Space.s),
        const _QuietBlock(
          child: SelectableText(_adbCommand, style: TextStyle(fontFamily: 'monospace')),
        ),
      ];
}

class _StatusBanner extends StatelessWidget {
  final bool ready;
  final bool loading;
  const _StatusBanner({required this.ready, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const LinearProgressIndicator();
    final background = ready ? context.money.incomeContainer : context.colors.tertiaryContainer;
    final foreground =
        ready ? context.money.onIncomeContainer : context.colors.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Corners.large),
      ),
      child: Row(children: [
        Icon(ready ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: foreground),
        const SizedBox(width: Space.m),
        Expanded(
          child: Text(
            ready
                ? 'Auto-capture is on. Payments will show up as alerts.'
                : 'Auto-capture is off. Finish the steps below.',
            style: context.text.titleSmall?.copyWith(color: foreground),
          ),
        ),
      ]),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final bool done;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? help;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.done,
    required this.actionLabel,
    required this.onAction,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    return GroupCard(
      padding: const EdgeInsets.all(Space.l),
      children: [
        _StepTitle(number: number, done: done, title: title),
        const SizedBox(height: Space.s),
        _MutedText(description),
        if (!done) ...[
          const SizedBox(height: Space.m),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
        if (help != null) ...[const SizedBox(height: Space.m), help!],
      ],
    );
  }
}

/// The step's number (or a check once done) and its title.
class _StepTitle extends StatelessWidget {
  final int number;
  final bool done;
  final String title;
  const _StepTitle({required this.number, required this.done, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StepBadge(number: number, done: done),
      const SizedBox(width: Space.m),
      Expanded(child: Text(title, style: context.text.titleMedium)),
    ]);
  }
}

class _StepBadge extends StatelessWidget {
  final int number;
  final bool done;
  const _StepBadge({required this.number, required this.done});

  @override
  Widget build(BuildContext context) {
    if (done) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: context.money.incomeContainer,
        child: Icon(Icons.check_rounded, size: 18, color: context.money.income),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: context.colors.primaryContainer,
      child: Text('$number',
          style: context.text.labelLarge?.copyWith(color: context.colors.onPrimaryContainer)),
    );
  }
}

/// Android 13+ blocks notification access for apps installed from a file
/// until "Allow restricted settings" is turned on in App info.
class _RestrictedSettingsHelp extends StatelessWidget {
  /// For SMS, Android shows no prompt at all instead of a greyed-out switch.
  final bool sms;
  const _RestrictedSettingsHelp({this.sms = false});

  @override
  Widget build(BuildContext context) {
    return _QuietBlock(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sms ? 'Nothing happened when you tapped Allow?' : 'Switch greyed out or "Restricted setting"?',
            style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        _MutedText(sms
            ? 'Android blocks SMS access for apps installed from a file. Open App info, '
                'tap ⋮ (top right) → Allow restricted settings, then Permissions → SMS → '
                'Allow. You only do this once.'
            : 'Android blocks this for apps installed from a file. '
                'Open App info, tap ⋮ (top right) → Allow restricted settings. '
                'Then come back and tap Allow again. You only do this once.'),
        const Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: CaptureChannel.openAppInfo,
            child: Text('Open App info'),
          ),
        ),
      ]),
    );
  }
}

class _HowSuggestionsWork extends StatelessWidget {
  const _HowSuggestionsWork();

  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('Suggestions'),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.xs),
        child: _MutedText('PaiPai never files a payment by itself. The alert offers '
            'what you usually pick for that shop (e.g. Groceries, then Food for '
            'Blinkit), and More shows every category. Fixing an entry in History '
            'improves the next suggestion.'),
      ),
    ]);
  }
}

/// A quiet tinted block for help text inside a card.
class _QuietBlock extends StatelessWidget {
  final Widget child;
  const _QuietBlock({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Corners.medium),
      ),
      child: child,
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;
  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant));
  }
}
