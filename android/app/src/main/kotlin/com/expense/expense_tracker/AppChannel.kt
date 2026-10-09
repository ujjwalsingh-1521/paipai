package com.expense.expense_tracker

import android.Manifest
import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The app engine's side of the capture channel: permission checks for the
 * setup screen, "open this payment" from a notification, and refresh
 * signals when the background engine saves something.
 */
object AppChannel {
    private const val PREFS = "capture_setup"
    private const val ASKED_NOTIFICATIONS = "asked_post_notifications"

    private val main = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private var launchPendingId: Int? = null

    fun attach(activity: Activity, messenger: BinaryMessenger) {
        this.activity = activity
        channel = MethodChannel(messenger, CaptureEngine.CHANNEL).also {
            it.setMethodCallHandler { call, result -> onCall(activity, call, result) }
        }
    }

    fun detach(activity: Activity) {
        if (this.activity !== activity) return
        this.activity = null
        channel = null
    }

    private var launchSetup = false
    private var launchScreen: String? = null

    /** Remembers what a notification opened the app for. */
    fun onLaunchIntent(intent: Intent?) {
        val screen = intent?.getStringExtra(PaiPaiWidgets.EXTRA_OPEN_SCREEN)
        if (screen != null) {
            intent.removeExtra(PaiPaiWidgets.EXTRA_OPEN_SCREEN)
            val open = channel
            if (open != null) open.invokeMethod("openScreen", screen) else launchScreen = screen
            return
        }
        if (intent?.getBooleanExtra(CaptureHealth.EXTRA_OPEN_SETUP, false) == true) {
            intent.removeExtra(CaptureHealth.EXTRA_OPEN_SETUP)
            val open = channel
            if (open != null) open.invokeMethod("openSetup", null) else launchSetup = true
            return
        }
        val id = takePendingId(intent) ?: return
        val open = channel
        if (open != null) open.invokeMethod("openPending", id) else launchPendingId = id
    }

    fun notifyDataChanged() {
        main.post { channel?.invokeMethod("dataChanged", null) }
    }

    private fun takePendingId(intent: Intent?): Int? {
        val id = intent?.getIntExtra(AlertNotifier.EXTRA_PENDING_ID, -1) ?: -1
        intent?.removeExtra(AlertNotifier.EXTRA_PENDING_ID)
        return id.takeIf { it >= 0 }
    }

    private fun onCall(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeLaunchPendingId" -> result.success(launchPendingId).also { launchPendingId = null }
            "takeLaunchSetup" -> result.success(launchSetup).also { launchSetup = false }
            "takeLaunchScreen" -> result.success(launchScreen).also { launchScreen = null }
            "captureHealth" -> result.success(CaptureHealth.status(activity))
            "resetHiddenCount" -> done(result) { CaptureHealth.resetHidden(activity) }
            "openNotificationSettings" -> done(result) { openNotificationSettings(activity) }
            "hasNotificationAccess" -> result.success(hasNotificationAccess(activity))
            "openNotificationAccessSettings" -> done(result) { openNotificationAccess(activity) }
            "canPostNotifications" -> result.success(canPostNotifications(activity))
            "requestPostNotifications" -> done(result) { requestPostNotifications(activity) }
            "openAppInfo" -> done(result) { openAppInfo(activity) }
            "canPinWidgets" -> result.success(canPinWidgets(activity))
            "pinWidget" -> result.success(pinWidget(activity, call.argument<String>("kind")))
            else -> if (!AlertNotifier.handle(activity, call, result)) result.notImplemented()
        }
    }

    // Actions with no result: reply null (Kotlin Unit cannot cross the channel).
    private inline fun done(result: MethodChannel.Result, action: () -> Unit) {
        action()
        result.success(null)
    }

    private fun hasNotificationAccess(context: Context) =
        NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)

    private fun openNotificationAccess(activity: Activity) {
        val component = ComponentName(activity, PaymentNotificationListener::class.java)
        val detail = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, component.flattenToString())
        } else null
        // Some phones lack the per-app page; fall back to the full list.
        if (detail == null || !tryStart(activity, detail)) {
            tryStart(activity, Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }

    private fun canPostNotifications(context: Context) =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    private fun requestPostNotifications(activity: Activity) {
        if (canPostNotifications(activity)) return
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val permission = Manifest.permission.POST_NOTIFICATIONS
        val canAsk = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED &&
            (!prefs.getBoolean(ASKED_NOTIFICATIONS, false) ||
                activity.shouldShowRequestPermissionRationale(permission))
        if (canAsk) {
            prefs.edit().putBoolean(ASKED_NOTIFICATIONS, true).apply()
            activity.requestPermissions(arrayOf(permission), 1001)
            return
        }
        // Android won't show the prompt again: open the app's notification settings.
        tryStart(activity, Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
    }

    // Where "Enhanced notifications" lives on Pixels.
    private fun openNotificationSettings(activity: Activity) {
        if (!tryStart(activity, Intent("android.settings.NOTIFICATION_SETTINGS"))) {
            tryStart(activity, Intent(Settings.ACTION_SETTINGS))
        }
    }

    private val widgetKinds = mapOf(
        "label" to LabelWidget::class.java, "pace" to PaceWidget::class.java,
        "categories" to CategoriesWidget::class.java, "add" to QuickAddWidget::class.java,
    )

    private fun canPinWidgets(context: Context) = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported

    /** Asks the launcher to add a widget; it shows its own "Add" prompt. */
    private fun pinWidget(context: Context, kind: String?): Boolean {
        val provider = widgetKinds[kind] ?: return false
        if (!canPinWidgets(context)) return false
        return AppWidgetManager.getInstance(context)
            .requestPinAppWidget(ComponentName(context, provider), null, null)
    }

    private fun openAppInfo(activity: Activity) {
        tryStart(activity, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null)))
    }

    private fun tryStart(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (e: ActivityNotFoundException) {
        false
    }
}
