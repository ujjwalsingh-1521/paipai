package com.expense.expense_tracker

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The small "pick a category" card opened by More on a payment alert. It is
 * a see-through screen running the Dart entrypoint `quickPickMain`, shown
 * over whatever app the user is in, and closes once they choose. It opens
 * only because the user tapped, so no "display over other apps" permission
 * is needed.
 */
class QuickPickActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName() = "quickPickMain"

    override fun getBackgroundMode() = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CaptureEngine.CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickerPendingId" -> result.success(
                    intent.getIntExtra(AlertNotifier.EXTRA_PENDING_ID, -1).takeIf { it >= 0 })
                "pickerMode" -> result.success(intent.getStringExtra(EXTRA_MODE) ?: "pick")
                // Alert updates and refresh signals, as in the other engines.
                else -> if (!AlertNotifier.handle(this, call, result)) result.notImplemented()
            }
        }
    }

    companion object {
        const val EXTRA_MODE = "mode"

        /** The Quick add widget: the same see-through card, showing the + sheet. */
        fun addIntent(context: Context): PendingIntent {
            val intent = Intent(context, QuickPickActivity::class.java)
                .putExtra(EXTRA_MODE, "add")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            return PendingIntent.getActivity(context, 9004, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun intent(context: Context, pendingId: Int): PendingIntent {
            val intent = Intent(context, QuickPickActivity::class.java)
                .putExtra(AlertNotifier.EXTRA_PENDING_ID, pendingId)
                // A fresh card each time, in its own task, so closing it
                // returns to the app the user was in.
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            return PendingIntent.getActivity(context, pendingId * 10 + 8, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }
}
