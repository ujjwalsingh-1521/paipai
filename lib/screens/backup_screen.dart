import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/balance_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../providers/income_source_provider.dart';
import '../providers/pending_transaction_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup/backup_file.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/backup_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

final _dateTime = DateFormat('d MMM yyyy, h:mm a');

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _service = BackupService();
  AutoBackupStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await _service.autoStatus();
    if (mounted) setState(() => _status = status);
  }

  /// Runs [action] with a busy indicator; shows any error as a snackbar.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast(BackupService.describeError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _loadStatus();
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: isError ? TextStyle(color: colors.onError) : null),
      backgroundColor: isError ? colors.error : null,
    ));
  }

  Future<void> _backUpNow() async {
    await _service.runAutoBackupNow();
    _toast('Saved to ${BackupStorage.folderLabel}');
  }

  Future<void> _setAutoEnabled(bool enabled) async {
    await _service.setAutoEnabled(enabled);
    if (enabled) await _service.runAutoBackupIfDue();
  }

  Future<void> _restore() async {
    final backup = await _service.pickBackup();
    if (backup == null || !mounted) return;
    if (!await _confirmRestore(backup)) return;
    await _service.restore(backup);
    _refreshAllData();
    _toast('Restored backup from ${_dateTime.format(backup.createdAt)}');
  }

  Future<bool> _confirmRestore(BackupFile backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: Text(_restoreSummary(backup)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.colors.error, foregroundColor: context.colors.onError),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _restoreSummary(BackupFile backup) =>
      'Backup from ${_dateTime.format(backup.createdAt)}:\n'
      '• ${backup.countOf('expenses')} expenses\n'
      '• ${backup.countOf('income')} income entries\n'
      '• ${backup.countOf('categories')} categories\n\n'
      'Everything currently in the app will be replaced. A copy of your '
      'current data is saved to ${BackupStorage.folderLabel} first.';

  /// Every provider reads from the DB, so reload them all after a restore.
  void _refreshAllData() {
    ref.invalidate(expenseProvider);
    ref.invalidate(incomeProvider);
    ref.invalidate(balanceStartProvider);
    ref.invalidate(budgetProvider);
    ref.invalidate(categoryProvider);
    ref.invalidate(incomeSourceProvider);
    ref.invalidate(pendingTransactionProvider);
    ref.invalidate(themeModeProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.xxl),
          children: [
            if (_busy) ...[const LinearProgressIndicator(), const SizedBox(height: Space.m)],
            _shareCard(),
            const SizedBox(height: Space.m),
            _restoreCard(),
            const SizedBox(height: Space.m),
            _autoCard(),
          ],
        ),
      ),
    );
  }

  Widget _shareCard() => _Section(
        icon: Icons.backup_rounded,
        title: 'Back up now',
        description: 'Creates one file with all your data. Save it to '
            'Google Drive, send it on WhatsApp, or keep it in Files.',
        child: FilledButton.icon(
          onPressed: () => _run(_service.shareBackup),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Create backup'),
        ),
      );

  Widget _restoreCard() => _Section(
        icon: Icons.restore_rounded,
        title: 'Restore',
        description: 'Replaces all data in the app with a backup file. '
            'Your current data is saved first, just in case.',
        child: FilledButton.tonalIcon(
          onPressed: () => _run(_restore),
          icon: const Icon(Icons.settings_backup_restore_rounded),
          label: const Text('Restore from file'),
        ),
      );

  Widget _autoCard() {
    final status = _status;
    return _Section(
      icon: Icons.schedule_rounded,
      title: 'Daily automatic backup',
      description: 'Once a day, saves a backup to ${BackupStorage.folderLabel}. '
          'Keeps the last ${BackupService.keepDailyBackups} days. The '
          'files stay even if the app is uninstalled.',
      trailing: Switch(
        value: (status?.enabled ?? false) && (status?.supported ?? false),
        onChanged: status?.supported == true
            ? (on) => _run(() => _setAutoEnabled(on))
            : null,
      ),
      child: status == null ? null : _AutoStatusView(
        status: status,
        onBackUpNow: () => _run(_backUpNow),
      ),
    );
  }
}

class _AutoStatusView extends StatelessWidget {
  final AutoBackupStatus status;
  final VoidCallback onBackUpNow;

  const _AutoStatusView({required this.status, required this.onBackUpNow});

  @override
  Widget build(BuildContext context) {
    if (!status.supported) {
      return const _StatusText(
          'Needs Android 10 or newer. Use "Create backup" instead.',
          isError: true);
    }
    final last = status.lastBackupAt;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StatusText(last == null
          ? 'No automatic backup yet.'
          : 'Last backup: ${_dateTime.format(last)}'),
      if (status.lastError != null)
        _StatusText('Last attempt failed: ${status.lastError}', isError: true),
      const SizedBox(height: Space.m),
      OutlinedButton(onPressed: onBackUpNow, child: const Text('Back up now')),
    ]);
  }
}

class _StatusText extends StatelessWidget {
  final String text;
  final bool isError;

  const _StatusText(this.text, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Text(text,
          style: context.text.bodySmall
              ?.copyWith(color: isError ? colors.error : colors.onSurfaceVariant)),
    );
  }
}

/// One settings block: icon and title (with an optional switch), what it
/// does, then its button or status.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;
  final Widget? child;

  const _Section({
    required this.icon,
    required this.title,
    required this.description,
    this.trailing,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GroupCard(
      padding: const EdgeInsets.all(Space.l),
      children: [
        _header(context),
        const SizedBox(height: Space.s),
        Text(description,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        if (child != null) ...[
          const SizedBox(height: Space.m),
          Align(alignment: Alignment.centerLeft, child: child),
        ],
      ],
    );
  }

  Widget _header(BuildContext context) => Row(children: [
        Icon(icon, color: context.colors.primary),
        const SizedBox(width: Space.m),
        Expanded(child: Text(title, style: context.text.titleMedium)),
        ?trailing,
      ]);
}
