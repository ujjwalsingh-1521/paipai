package com.expense.expense_tracker

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Android 15+ replaces notifications it thinks contain one-time codes with
 * "Sensitive notification content hidden" for apps like PaiPai. Bank SMS are
 * sometimes caught too. This records when that happens so the setup screen
 * can explain the one-time fix. Real OTP messages are hidden too, and they
 * look the same to us, so the user is warned only once, ever.
 */
object CaptureHealth {
    private const val PREFS = "capture_health"
    private const val HIDDEN_COUNT = "hidden_count"
    private const val LAST_HIDDEN_AT = "last_hidden_at"
    private const val LAST_WARNED_AT = "last_warned_at"
    private const val WARNING_CHANNEL = "capture_setup"
    private const val WARNING_ID = Int.MAX_VALUE - 1
    const val EXTRA_OPEN_SETUP = "open_capture_setup"

    // App-op behind RECEIVE_SENSITIVE_NOTIFICATIONS (Android 15+).
    private const val SENSITIVE_OP = "android:receive_sensitive_notifications"
    private val placeholder = Regex("sensitive notification content hidden", RegexOption.IGNORE_CASE)

    fun isHiddenByAndroid(message: Map<String, Any?>): Boolean =
        placeholder.containsMatchIn(message["text"]?.toString().orEmpty())

    fun recordHidden(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        prefs.edit()
            .putInt(HIDDEN_COUNT, prefs.getInt(HIDDEN_COUNT, 0) + 1)
            .putLong(LAST_HIDDEN_AT, now)
            .apply()
        if (prefs.getLong(LAST_WARNED_AT, 0) == 0L && !canReadSensitive(context)) {
            prefs.edit().putLong(LAST_WARNED_AT, now).apply()
            warn(context)
        }
    }

    /** Always true below Android 15, where nothing is hidden. */
    fun canReadSensitive(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 35) return true
        return try {
            val appOps = context.getSystemService(AppOpsManager::class.java)
            appOps.unsafeCheckOpNoThrow(SENSITIVE_OP, Process.myUid(), context.packageName) ==
                AppOpsManager.MODE_ALLOWED
        } catch (e: IllegalArgumentException) {
            false // op unknown on this phone
        }
    }

    fun status(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "affected" to (Build.VERSION.SDK_INT >= 35),
            "canReadSensitive" to canReadSensitive(context),
            "hiddenCount" to prefs.getInt(HIDDEN_COUNT, 0),
            "lastHiddenAt" to prefs.getLong(LAST_HIDDEN_AT, 0).takeIf { it > 0 },
        )
    }

    fun resetHidden(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(HIDDEN_COUNT).remove(LAST_HIDDEN_AT).apply()
    }

    private fun warn(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(WARNING_CHANNEL, "Setup problems", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val open = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN_SETUP, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(context, WARNING_ID, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, WARNING_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_paipai)
            .setColor(0xFF2563EB.toInt())
            .setContentTitle("Android may hide bank SMS from PaiPai")
            .setContentText("Tap to check the one-time setting, so SMS payments aren't missed.")
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(WARNING_ID, notification)
        } catch (e: SecurityException) {
            // Notifications off: the setup screen still shows the problem.
        }
    }
}
