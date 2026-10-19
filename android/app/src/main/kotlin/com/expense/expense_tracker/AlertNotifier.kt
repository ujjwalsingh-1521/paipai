package com.expense.expense_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Posts the payment alerts the Dart CaptureService asks for: "₹250 paid ·
 * Store" with the two suggested categories plus More (a small card with
 * every category, see QuickPickActivity). Tapping the alert itself opens
 * the app on that payment. The notification id is the pending
 * transaction's id, so updates replace instead of stacking.
 */
object AlertNotifier {
    private const val REVIEW_CHANNEL = "payment_review"
    private const val BUDGET_CHANNEL = "budget_alerts"
    const val EXTRA_PENDING_ID = "pending_id"
    const val EXTRA_CATEGORY = "category"
    const val EXTRA_FROM_WIDGET = "from_widget"

    /** Handles alert calls from either Flutter engine; false if not ours. */
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "showAlert" -> show(context, call)
            "showBudgetAlert" -> showBudget(context, call)
            "cancelAlert" -> NotificationManagerCompat.from(context).cancel(call.argument<Int>("id")!!)
            "dataChanged" -> AppChannel.notifyDataChanged()
            "updateWidgets" -> PaiPaiWidgets.update(context, call.argument<String>("snapshot"))
            else -> return false
        }
        result.success(null)
        return true
    }

    private fun show(context: Context, call: MethodCall) {
        ensureChannels(context)
        val id = call.argument<Int>("id")!!
        val builder = NotificationCompat.Builder(context, REVIEW_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_paipai)
            .setColor(0xFF2563EB.toInt())
            .setContentTitle(call.argument<String>("title"))
            .setContentText(call.argument<String>("text"))
            .setContentIntent(openAppIntent(context, id))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setSilent(call.argument<Boolean>("silent") == true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
        call.argument<List<String>>("categories").orEmpty().forEachIndexed { index, category ->
            builder.addAction(0, category, categoryIntent(context, id, category, index))
        }
        builder.addAction(0, "More", QuickPickActivity.intent(context, id))
        try {
            NotificationManagerCompat.from(context).notify(id, builder.build())
        } catch (e: SecurityException) {
            // Notifications not allowed: the payment still waits in the app.
        }
    }

    /** Also used by the Label payments widget's category buttons. */
    /**
     * A category button. The widget's buttons get their own request codes
     * (3, 4) so they don't overwrite the notification's (0, 1) extras.
     */
    fun categoryIntent(context: Context, id: Int, category: String, index: Int, fromWidget: Boolean = false): PendingIntent {
        val intent = Intent(context, AlertActionReceiver::class.java)
            .putExtra(EXTRA_PENDING_ID, id)
            .putExtra(EXTRA_CATEGORY, category)
            .putExtra(EXTRA_FROM_WIDGET, fromWidget)
        val code = id * 10 + index + if (fromWidget) 3 else 0
        return PendingIntent.getBroadcast(context, code, intent, flags())
    }

    fun openAppIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_PENDING_ID, id)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(context, id * 10 + 9, intent, flags())
    }

    private fun flags() = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    /** "80% of your October budget used"; tapping it opens Insights. */
    private fun showBudget(context: Context, call: MethodCall) {
        ensureChannels(context)
        val notification = NotificationCompat.Builder(context, BUDGET_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_paipai)
            .setColor(0xFF2563EB.toInt())
            .setContentTitle(call.argument<String>("title"))
            .setContentText(call.argument<String>("text"))
            .setContentIntent(PaiPaiWidgets.openInsights(context))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(call.argument<Int>("id")!!, notification)
        } catch (_: SecurityException) {
            // Notifications are turned off for PaiPai; nothing to show.
        }
    }

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            REVIEW_CHANNEL, "Payments to review", NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "A payment was detected: pick what it was for." })
        manager.createNotificationChannel(NotificationChannel(
            BUDGET_CHANNEL, "Budget alerts", NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = "When a budget reaches a warning level or runs out." })
        // Left over from 1.2.0 and earlier, which filed some payments silently.
        manager.deleteNotificationChannel("payment_filed")
    }
}

/** A category button on a review alert was tapped. */
class AlertActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(AlertNotifier.EXTRA_PENDING_ID, -1)
        val category = intent.getStringExtra(AlertNotifier.EXTRA_CATEGORY) ?: return
        if (id < 0) return
        NotificationManagerCompat.from(context).cancel(id)
        // Show the result now: saving needs the capture engine, which can
        // take seconds to start when the app is closed.
        val saved = PaiPaiWidgets.markHandled(context, id)
        if (intent.getBooleanExtra(AlertNotifier.EXTRA_FROM_WIDGET, false)) {
            val message = if (saved != null) "Saved $saved to $category" else "Saved to $category"
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
        // Keep the process alive while the capture engine starts and saves,
        // but no longer: Android delivers PaiPai's next broadcast (the next
        // tap) only after this one finishes.
        val finish = finishOnce(goAsync())
        CaptureEngine.deliver(context, "onAlertAction", mapOf("pendingId" to id, "category" to category)) { _, _ -> finish() }
        Handler(Looper.getMainLooper()).postDelayed(finish, MAX_WAIT_MS)
    }

    companion object {
        /** A cold engine start plus the save rarely takes more than a few seconds. */
        const val MAX_WAIT_MS = 8_000L
    }
}
