import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../db/database_helper.dart';

import 'capture_service.dart';
import 'parsed_payment.dart';

/// Bank SMS from the phone's inbox (SmsCapture.kt), for the ones PaiPai
/// didn't see arrive. Both run in the background capture engine, in line
/// with live SMS, so the same message is never recorded twice.
class SmsInbox {
  static const _channel = MethodChannel('com.expense.expense_tracker/capture');

  /// Catch-up: SMS received since the last scan (phone was off, app was
  /// killed). Recent ones still get an alert; see [CaptureService.catchUpAlertAge].
  static Future<void> catchUp(CaptureService service) async {
    final status = await _channel.invokeMapMethod<String, Object?>('smsStatus');
    final cursor = status?['cursor'] as int?;
    if (status?['granted'] != true || cursor == null) return;
    await _read(service, after: cursor, mode: CaptureMode.catchUp, saveCursor: true);
  }

  /// Import: payment SMS received since [from], chosen by the user. They
  /// wait in the app to be labelled; nothing is alerted. Returns how many
  /// new payments it found (ones already recorded don't count).
  static Future<int> import(CaptureService service, DateTime from) async {
    final db = DatabaseHelper();
    final lastId = await db.maxId('pending_transactions');
    await _read(service, after: from.millisecondsSinceEpoch, mode: CaptureMode.import, saveCursor: false);
    return (await db.getAllPendingTransactions(unprocessedOnly: false)).where((t) => t.id! > lastId).length;
  }

  static Future<void> _read(CaptureService service,
      {required int after, required CaptureMode mode, required bool saveCursor}) async {
    final until = DateTime.now().millisecondsSinceEpoch;
    var more = true;
    while (more) {
      final page = await _channel.invokeMapMethod<String, Object?>(
          'readSmsInbox', {'after': after, 'until': until});
      if (page == null) break; // permission was taken away
      final messages = (page['messages'] as List<Object?>).cast<Map<Object?, Object?>>();
      for (final message in messages) {
        try {
          await service.handleNotification(NotificationInput.fromMap(message), mode: mode);
        } catch (error) {
          // One unreadable SMS must not stop every later scan at the same spot.
          debugPrint('PaiPaiCapture: an inbox SMS failed: $error');
        }
      }
      final scannedUntil = page['scannedUntil'] as int;
      more = page['more'] == true;
      // A full page may end between two SMS received in the same
      // millisecond: re-read that moment (the fingerprint skips repeats).
      after = more ? scannedUntil - 1 : scannedUntil;
      if (saveCursor) await _channel.invokeMethod('setSmsCursor', {'millis': scannedUntil});
    }
    await service.batchDone();
  }
}
