import 'package:flutter/services.dart';

/// Writes backups to the public Downloads/PaiPai folder (via Android's
/// MediaStore), so they survive the app being uninstalled.
/// Requires Android 10+; see BackupChannelHandler.kt.
class BackupStorage {
  static const _channel = MethodChannel('com.expense.expense_tracker/backup');
  static const folderLabel = 'Downloads/PaiPai';

  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('isSupported') ?? false;

  /// Creates [fileName], or overwrites it if this install already made it.
  Future<void> save(String fileName, String content) => _channel
      .invokeMethod('save', {'fileName': fileName, 'content': content});

  /// Deletes all but the newest [keep] files whose names start with [prefix].
  Future<void> prune({required String prefix, required int keep}) =>
      _channel.invokeMethod('prune', {'prefix': prefix, 'keep': keep});
}
