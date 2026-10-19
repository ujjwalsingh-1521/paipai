import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/pending_transaction.dart';
import 'capture_alerts.dart';
import 'capture_service.dart';
import 'parsed_payment.dart';
import 'sms_inbox.dart';
import '../budgets/budget_check.dart';
import '../widgets/widget_sync.dart';

/// Bridge to the native side (PaymentNotificationListener, CaptureEngine,
/// AlertNotifier and MainActivity in Kotlin). The same channel name exists
/// in both Flutter engines: the background capture engine and the app.
class CaptureChannel {
  static const _channel = MethodChannel('com.expense.expense_tracker/capture');
  static const _replyWithin = Duration(seconds: 2);

  // --- Background engine ---

  /// Starts receiving notifications and alert-button taps.
  static Future<void> startBackground(CaptureService service) async {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments as Map<Object?, Object?>? ?? const {};
      try {
        switch (call.method) {
          case 'onNotification':
            // The SMS receiver holds PaiPai's broadcasts until this replies;
            // behind an import or scan, reply early and let it finish.
            await service
                .handleNotification(NotificationInput.fromMap(args))
                .timeout(_replyWithin, onTimeout: () {});
          case 'onAlertAction':
            await service.categorize(args['pendingId'] as int, args['category'] as String);
          case 'refreshWidgets':
            await WidgetSync.push();
          case 'scanSms':
            await SmsInbox.catchUp(service);
          case 'importSms':
            return await SmsInbox.import(
                service, DateTime.fromMillisecondsSinceEpoch(args['from'] as int));
        }
        return null;
      } catch (error, stack) {
        // Nobody awaits these calls natively, so make failures visible in logcat.
        debugPrint('PaiPaiCapture: ${call.method} failed: $error\n$stack');
        rethrow;
      }
    });
    // Native code queues events until this arrives.
    await _channel.invokeMethod('backgroundReady');
  }

  // --- App engine ---

  /// [onOpenPending] fires when a notification's Other/tap opens the app.
  static void listenInApp({
    required void Function(int pendingId) onOpenPending,
    required void Function() onOpenSetup,
    required void Function() onDataChanged,
    required void Function(String screen) onOpenScreen,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openPending':
          onOpenPending(call.arguments as int);
        case 'openSetup':
          onOpenSetup();
        case 'dataChanged':
          onDataChanged();
        case 'openScreen':
          onOpenScreen(call.arguments as String);
      }
    });
  }

  /// Pending id the app was launched for (from a notification), once.
  static Future<int?> takeLaunchPendingId() =>
      _channel.invokeMethod<int>('takeLaunchPendingId');

  /// Screen a home-screen widget opened the app on ('insights'), once.
  static Future<String?> takeLaunchScreen() => _channel.invokeMethod<String>('takeLaunchScreen');

  /// 'add' when the card was opened by the Quick add widget, else 'pick'.
  static Future<String> pickerMode() async =>
      await _channel.invokeMethod<String>('pickerMode') ?? 'pick';

  /// The payment the More card (QuickPickActivity) was opened for.
  static Future<int?> pickerPendingId() =>
      _channel.invokeMethod<int>('pickerPendingId');

  /// True once, if the app was opened from the 'messages hidden' warning.
  static Future<bool> takeLaunchSetup() async =>
      await _channel.invokeMethod<bool>('takeLaunchSetup') ?? false;

  static Future<CaptureHealth> health() async => CaptureHealth.fromMap(
      await _channel.invokeMethod<Map<Object?, Object?>>('captureHealth') ?? const {});

  static Future<void> resetHiddenCount() => _channel.invokeMethod('resetHiddenCount');

  /// Android's notification settings (where 'Enhanced notifications' is).
  static Future<void> openNotificationSettings() =>
      _channel.invokeMethod('openNotificationSettings');

  static Future<bool> hasNotificationAccess() async =>
      await _channel.invokeMethod<bool>('hasNotificationAccess') ?? false;

  static Future<void> openNotificationAccessSettings() =>
      _channel.invokeMethod('openNotificationAccessSettings');

  static Future<bool> canPostNotifications() async =>
      await _channel.invokeMethod<bool>('canPostNotifications') ?? false;

  /// Asks for the notification permission (Android 13+), or opens the
  /// app's notification settings if Android won't ask again.
  static Future<void> requestPostNotifications() =>
      _channel.invokeMethod('requestPostNotifications');

  /// Whether the launcher can add a widget when asked (most can).
  static Future<bool> canPinWidgets() async =>
      await _channel.invokeMethod<bool>('canPinWidgets') ?? false;

  /// Asks the launcher to add a home-screen widget: 'label', 'pace',
  /// 'categories' or 'add'. The launcher shows its own confirmation.
  static Future<bool> pinWidget(String kind) async =>
      await _channel.invokeMethod<bool>('pinWidget', {'kind': kind}) ?? false;

  /// For Android's "Allow restricted settings" step.
  static Future<void> openAppInfo() => _channel.invokeMethod('openAppInfo');

  // --- Bank SMS (SmsCapture.kt) ---

  static Future<SmsStatus> smsStatus() async =>
      SmsStatus.fromMap(await _channel.invokeMapMethod<String, Object?>('smsStatus') ?? const {});

  /// Shows Android's SMS prompt. 'blocked' means Android didn't ask (a
  /// restricted setting, or "Don't allow" chosen before): fix in App info.
  static Future<String> requestSmsPermission() async =>
      await _channel.invokeMethod<String>('requestSmsPermission') ?? 'denied';

  /// Also read bank and UPI app notifications (needs Notification access).
  static Future<void> setAppAlerts(bool enabled) =>
      _channel.invokeMethod('setAppAlerts', {'enabled': enabled});

  /// Looks for bank SMS that arrived while PaiPai couldn't run.
  static Future<void> requestSmsScan() => _channel.invokeMethod('requestSmsScan');

  /// Brings in payment SMS received since [from]; returns how many new payments it found.
  static Future<int> importSms(DateTime from) async =>
      await _channel
          .invokeMethod<int>('importSms', {'from': from.millisecondsSinceEpoch})
          // The capture engine didn't answer (it failed to start).
          .timeout(const Duration(minutes: 10)) ??
      0;
}

/// Whether PaiPai can read bank SMS, and whether app notifications are on too.
class SmsStatus {
  final bool granted;
  final bool appAlerts;

  const SmsStatus({required this.granted, required this.appAlerts});

  factory SmsStatus.fromMap(Map<String, Object?> map) => SmsStatus(
        granted: map['granted'] as bool? ?? false,
        appAlerts: map['appAlerts'] as bool? ?? false,
      );
}

/// Whether Android 15+ is hiding bank messages from PaiPai (see CaptureHealth.kt).
class CaptureHealth {
  /// Android 15+, which can hide messages it thinks hold one-time codes.
  final bool affected;

  /// PaiPai was allowed to read such messages (one-time adb step).
  final bool canReadSensitive;
  final int hiddenCount;
  final DateTime? lastHiddenAt;

  const CaptureHealth({
    required this.affected,
    required this.canReadSensitive,
    required this.hiddenCount,
    this.lastHiddenAt,
  });

  factory CaptureHealth.fromMap(Map<Object?, Object?> map) {
    final last = map['lastHiddenAt'] as int?;
    return CaptureHealth(
      affected: map['affected'] as bool? ?? false,
      canReadSensitive: map['canReadSensitive'] as bool? ?? true,
      hiddenCount: map['hiddenCount'] as int? ?? 0,
      lastHiddenAt: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
    );
  }

  /// Messages were hidden recently and PaiPai still can't read them.
  bool get needsFix =>
      affected &&
      !canReadSensitive &&
      lastHiddenAt != null &&
      DateTime.now().difference(lastHiddenAt!) < const Duration(days: 7);
}

/// Posts alerts as Android notifications via AlertNotifier.kt.
class NativeCaptureAlerts implements CaptureAlerts {
  static const _channel = MethodChannel('com.expense.expense_tracker/capture');

  @override
  Future<void> showReview(PendingTransaction tx, Suggestions suggestions,
          {bool update = false}) =>
      _channel.invokeMethod('showAlert', {
        'id': tx.id,
        'title': AlertText.reviewTitle(tx),
        'text': AlertText.reviewBody(tx, usual: suggestions.usual),
        'categories': suggestions.forNotification,
        'silent': update,
      });

  @override
  Future<void> cancel(int pendingId) =>
      _channel.invokeMethod('cancelAlert', {'id': pendingId});

  @override
  Future<void> dataChanged() async {
    await _channel.invokeMethod('dataChanged');
    await WidgetSync.push();
    await BudgetCheck.run();
  }
}
