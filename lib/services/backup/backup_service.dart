import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../db/database_helper.dart';
import 'backup_file.dart';
import 'backup_storage.dart';

/// Status of the automatic daily backup, shown on the Backup screen.
class AutoBackupStatus {
  final bool enabled;
  final bool supported;
  final DateTime? lastBackupAt;
  final String? lastError;

  const AutoBackupStatus({
    required this.enabled,
    required this.supported,
    this.lastBackupAt,
    this.lastError,
  });
}

class BackupService {
  static const keepDailyBackups = 7;
  static const _autoInterval = Duration(hours: 24);
  static const _enabledKey = 'auto_backup_enabled';
  static const _lastAtKey = 'auto_backup_last_at';
  static const _errorKey = 'auto_backup_error';

  // Guards against overlapping runs (e.g. app paused and resumed quickly).
  static bool _autoRunning = false;

  final DatabaseHelper _db;
  final BackupStorage _storage;

  BackupService({DatabaseHelper? db, BackupStorage? storage})
      : _db = db ?? DatabaseHelper(),
        _storage = storage ?? BackupStorage();

  Future<BackupFile> createBackup() async => BackupFile(
        schemaVersion: DatabaseHelper.schemaVersion,
        createdAt: DateTime.now(),
        tables: await _db.dumpTables(),
      );

  /// Opens the share sheet with a fresh backup (Drive, WhatsApp, Files...).
  Future<void> shareBackup() async {
    final backup = await createBackup();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, BackupNames.manual(backup.createdAt)));
    await file.writeAsString(backup.encode());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'PaiPai backup',
    ));
  }

  /// Lets the user pick a backup file. Returns null if they cancel;
  /// throws [BackupException] if the file isn't a usable backup.
  Future<BackupFile?> pickBackup() async {
    final picked = await FilePicker.pickFile(dialogTitle: 'Choose a PaiPai backup');
    if (picked == null) return null;
    final String text;
    try {
      text = utf8.decode(await picked.readAsBytes());
    } on FormatException {
      throw const BackupException('This file is damaged or not a backup.');
    }
    return BackupFile.decode(
      text,
      currentSchemaVersion: DatabaseHelper.schemaVersion,
      requiredTables: DatabaseHelper.backupTables,
    );
  }

  /// Replaces all data with [backup], after saving a safety copy of the
  /// current data so the restore itself can be undone.
  Future<void> restore(BackupFile backup) async {
    await _saveSafetyCopy();
    final deviceSettings = await _readAutoBackupSettings();
    await _db.replaceAllTables(backup.tables);
    // Auto-backup state belongs to this phone, not to the backup's contents.
    for (final entry in deviceSettings.entries) {
      await _db.setSetting(entry.key, entry.value);
    }
  }

  Future<Map<String, String>> _readAutoBackupSettings() async => {
        for (final key in [_enabledKey, _lastAtKey, _errorKey])
          key: ?await _db.getSetting(key),
      };

  Future<void> _saveSafetyCopy() async {
    final current = await createBackup();
    final name = BackupNames.beforeRestore(current.createdAt);
    if (await _storage.isSupported()) {
      await _storage.save(name, current.encode());
      return;
    }
    // Android 9 and older: keep it in app storage instead.
    final dir = await getApplicationDocumentsDirectory();
    await File(p.join(dir.path, name)).writeAsString(current.encode());
  }

  // --- Automatic daily backup ---

  Future<AutoBackupStatus> autoStatus() async {
    final lastAt = await _db.getSetting(_lastAtKey);
    final error = await _db.getSetting(_errorKey);
    return AutoBackupStatus(
      enabled: await _db.getSetting(_enabledKey) != 'false',
      supported: await _storage.isSupported(),
      lastBackupAt: lastAt == null ? null : DateTime.tryParse(lastAt),
      lastError: (error == null || error.isEmpty) ? null : error,
    );
  }

  Future<void> setAutoEnabled(bool enabled) =>
      _db.setSetting(_enabledKey, '$enabled');

  /// Runs the daily backup if it's on and 24h have passed. Never throws:
  /// failures are recorded and shown on the Backup screen.
  Future<void> runAutoBackupIfDue() async {
    final status = await autoStatus();
    if (!status.enabled || !status.supported) return;
    final last = status.lastBackupAt;
    if (last != null && DateTime.now().difference(last) < _autoInterval) return;
    try {
      await runAutoBackupNow();
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }

  /// Saves today's backup to Downloads/PaiPai and keeps the newest 7.
  /// Records the outcome, then rethrows any failure.
  Future<void> runAutoBackupNow() async {
    if (_autoRunning) return;
    _autoRunning = true;
    try {
      final backup = await createBackup();
      await _storage.save(BackupNames.daily(backup.createdAt), backup.encode());
      await _storage.prune(prefix: BackupNames.dailyPrefix, keep: keepDailyBackups);
      await _db.setSetting(_lastAtKey, backup.createdAt.toIso8601String());
      await _db.setSetting(_errorKey, '');
    } catch (e) {
      await _db.setSetting(_errorKey, describeError(e));
      rethrow;
    } finally {
      _autoRunning = false;
    }
  }

  /// A short, user-readable message for errors from storage or parsing.
  static String describeError(Object error) => switch (error) {
        PlatformException(:final message) => message ?? error.code,
        BackupException(:final message) => message,
        _ => '$error',
      };
}
