import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../providers/theme_provider.dart';
import '../services/capture/capture_channel.dart';
import '../theme/app_theme.dart';
import '../services/budgets/budget_check.dart';
import '../services/widgets/widget_sync.dart';
import '../widgets/add_entry_sheet.dart';
import '../widgets/payment_review_sheet.dart';

/// The card opened by More on a payment alert (QuickPickActivity.kt): the
/// "What was this?" sheet for that one payment, drawn over whatever app is
/// open. Closes as soon as the sheet does.
class QuickPickApp extends ConsumerWidget {
  const QuickPickApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PaiPai',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeModeProvider),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const _QuickPickHost(),
    );
  }
}

class _QuickPickHost extends ConsumerStatefulWidget {
  const _QuickPickHost();

  @override
  ConsumerState<_QuickPickHost> createState() => _QuickPickHostState();
}

class _QuickPickHostState extends ConsumerState<_QuickPickHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickThenClose());
  }

  /// Always closes in the end: a see-through window left open would swallow
  /// every touch on the app underneath.
  Future<void> _pickThenClose() async {
    try {
      await _pick();
    } finally {
      await SystemNavigator.pop();
    }
  }

  Future<void> _pick() async {
    // The Quick add widget opens this card with the + sheet instead.
    if (await CaptureChannel.pickerMode() == 'add') {
      if (mounted) await showAddEntrySheet(context);
      await WidgetSync.push();
      await BudgetCheck.run();
      return;
    }
    final id = await CaptureChannel.pickerPendingId();
    final tx = id == null ? null : await DatabaseHelper().getPendingTransaction(id);
    // Already answered (e.g. from the alert's own buttons): nothing to ask.
    if (tx != null && !tx.isProcessed && mounted) {
      await showPaymentReviewSheet(context, tx);
    }
  }

  // See-through, so the app underneath stays visible around the card.
  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.transparent);
}
