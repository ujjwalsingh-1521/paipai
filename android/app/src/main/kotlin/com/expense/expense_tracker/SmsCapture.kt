package com.expense.expense_tracker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Bank SMS, read by PaiPai itself: the main way payments are captured.
 * New SMS arrive through [SmsCaptureReceiver] (also while the app is
 * closed); [readInbox] finds the ones missed while PaiPai couldn't run
 * (catch-up) or that came before it was installed (import). Messages go to
 * the same Dart code as notifications, with app = "sms" and title = sender.
 *
 * Optional app notifications: with SMS on, the notification listener skips
 * SMS apps (the same messages) and reads bank and UPI apps only if the user
 * turned that on. Without SMS permission, the listener reads everything.
 */
object SmsCapture {
    const val SOURCE = "sms"
    private const val PREFS = "capture_sources"
    private const val APP_ALERTS = "app_alerts_enabled"
    private const val CURSOR = "sms_scan_cursor"

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun granted(context: Context) = listOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)
        .all { context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    /** Whether bank and UPI app notifications are read too (off unless chosen). */
    fun appAlertsEnabled(context: Context) = prefs(context).getBoolean(APP_ALERTS, false)

    fun setAppAlertsEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(APP_ALERTS, enabled).commit()
    }

    /**
     * Where the last inbox scan stopped (an SMS's received time). Starts at
     * the moment SMS reading is first used, so old messages come in only
     * through an import the user asks for.
     */
    fun cursor(context: Context): Long {
        val prefs = prefs(context)
        if (!prefs.contains(CURSOR)) prefs.edit().putLong(CURSOR, System.currentTimeMillis()).commit()
        return prefs.getLong(CURSOR, 0)
    }

    fun setCursor(context: Context, millis: Long) {
        if (millis > cursor(context)) prefs(context).edit().putLong(CURSOR, millis).commit()
    }

    /**
     * One page of inbox SMS received after [after] and up to [until], oldest
     * first: {"messages": the ones that mention money, "scannedUntil": the
     * received time of the last SMS looked at, "more": whether the page was
     * full}. Null without permission. Runs off the main thread; [onResult]
     * is called on it.
     */
    fun readInbox(context: Context, after: Long, until: Long, onResult: (Map<String, Any?>?) -> Unit) {
        val app = context.applicationContext
        io.execute {
            // Without permission, or a messages provider that fails on some phones.
            val page = try {
                query(app, after, until)
            } catch (e: Exception) {
                Log.w(PaymentNotificationListener.TAG, "SMS inbox not readable: ${e.javaClass.simpleName}")
                null
            }
            main.post { onResult(page) }
        }
    }

    private const val PAGE = 500

    private fun query(context: Context, after: Long, until: Long): Map<String, Any?> {
        val columns = arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE, Telephony.Sms.DATE_SENT)
        val found = mutableListOf<Map<String, Any?>>()
        var scanned = 0
        var scannedUntil = after
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI, columns,
            "${Telephony.Sms.DATE} > ? AND ${Telephony.Sms.DATE} <= ?",
            arrayOf(after.toString(), until.toString()),
            "${Telephony.Sms.DATE} ASC",
        )?.use { cursor ->
            while (scanned < PAGE && cursor.moveToNext()) {
                scanned++
                val receivedAt = cursor.getLong(2)
                val item = item(cursor.getString(0).orEmpty(), cursor.getString(1).orEmpty(), cursor.getLong(3), receivedAt)
                if (NotificationText.mentionsMoney(item)) found += item
                scannedUntil = receivedAt
            }
        }
        return mapOf("messages" to found, "scannedUntil" to scannedUntil, "more" to (scanned == PAGE))
    }

    /** SMS calls from either Flutter engine; false if not ours. */
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "smsStatus" -> {
                val granted = granted(context)
                result.success(mapOf(
                    "granted" to granted,
                    "appAlerts" to appAlertsEnabled(context),
                    // Started only once SMS may be read, so catch-up never reaches back further.
                    "cursor" to if (granted) cursor(context) else null,
                ))
            }
            "setAppAlerts" -> {
                setAppAlertsEnabled(context, call.argument<Boolean>("enabled") == true)
                result.success(null)
            }
            "setSmsCursor" -> {
                setCursor(context, (call.argument<Number>("millis") ?: 0).toLong())
                result.success(null)
            }
            "readSmsInbox" -> readInbox(context,
                (call.argument<Number>("after") ?: 0).toLong(),
                (call.argument<Number>("until") ?: Long.MAX_VALUE).toLong(),
            ) { result.success(it) }
            else -> return false
        }
        return true
    }

    /** One SMS in the shape PaymentNotificationListener sends notifications. */
    fun item(sender: String, body: String, sentAt: Long, receivedAt: Long): Map<String, Any?> = mapOf(
        "app" to SOURCE,
        "title" to sender,
        "text" to body,
        "postedAt" to receivedAt,
        // The same id whether the SMS arrives live or is found in the inbox.
        "messageId" to "sms:$sender:${sentAt.takeIf { it > 0 } ?: receivedAt}",
    )

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** A new SMS: bank alerts go to the capture engine at once. */
class SmsCaptureReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!SmsCapture.granted(context)) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val now = System.currentTimeMillis()
        // A long SMS arrives in parts; join them per sender, in order.
        val messages = parts.filterNotNull()
            .groupBy { it.displayOriginatingAddress ?: it.originatingAddress.orEmpty() }
            .map { (sender, pieces) ->
                SmsCapture.item(sender, pieces.joinToString("") { it.displayMessageBody.orEmpty() },
                    pieces.first().timestampMillis, now)
            }
            .filter { NotificationText.mentionsMoney(it) }
        if (messages.isEmpty()) return
        Log.i(PaymentNotificationListener.TAG, "money SMS received")
        val finish = finishOnce(goAsync())
        val left = AtomicInteger(messages.size)
        for (message in messages) {
            CaptureEngine.deliver(context, "onNotification", message + ("mode" to "live")) { _, _ ->
                if (left.decrementAndGet() == 0) finish()
            }
        }
        Handler(Looper.getMainLooper()).postDelayed(finish, AlertActionReceiver.MAX_WAIT_MS)
    }
}

/** After a restart: look for bank SMS that arrived while the phone was off. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED || !SmsCapture.granted(context)) return
        val finish = finishOnce(goAsync())
        CaptureEngine.deliver(context, "scanSms", null) { _, _ -> finish() }
        Handler(Looper.getMainLooper()).postDelayed(finish, AlertActionReceiver.MAX_WAIT_MS)
    }
}

/** Ends a goAsync() broadcast exactly once (on the reply or the time limit). */
fun finishOnce(pending: BroadcastReceiver.PendingResult): () -> Unit {
    val finished = AtomicBoolean(false)
    return { if (finished.compareAndSet(false, true)) pending.finish() }
}
