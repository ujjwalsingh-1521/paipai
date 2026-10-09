package com.expense.expense_tracker

import android.app.Notification
import android.os.Bundle
import android.util.Log
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Android binds this once the user grants "Notification access", and keeps
 * it running (also after reboots) without a foreground service. Bank SMS
 * (via the Messages app), UPI apps, bank apps and email alerts all arrive
 * here. Only notifications that mention money are passed on; everything
 * else is dropped immediately.
 */
class PaymentNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val notification = sbn.notification ?: return
        val flags = notification.flags
        if (flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (flags and Notification.FLAG_ONGOING_EVENT != 0) return

        for (message in NotificationText.extract(sbn)) {
            if (CaptureHealth.isHiddenByAndroid(message)) {
                Log.i(TAG, "Android hid a notification from ${sbn.packageName}")
                CaptureHealth.recordHidden(applicationContext)
            } else if (NotificationText.mentionsMoney(message)) {
                // Logs the app only, never the message text.
                Log.i(TAG, "money notification from ${sbn.packageName}")
                CaptureEngine.deliver(applicationContext, "onNotification", message)
            }
        }
    }

    override fun onListenerConnected() {
        Log.i(TAG, "listener connected")
    }

    companion object {
        const val TAG = "PaiPaiCapture"
    }
}

/** Pulls the readable messages out of a notification. */
object NotificationText {
    // Older messages in a conversation notification are history, not new alerts.
    private const val MAX_MESSAGE_AGE_MS = 12 * 60 * 60 * 1000L

    private val money = Regex(
        """₹|\brs\.?\s?\d|\binr\b|\d\s?(?:inr|rs)\b|debited|credited""",
        RegexOption.IGNORE_CASE,
    )

    fun mentionsMoney(message: Map<String, Any?>): Boolean =
        money.containsMatchIn("${message["title"]} ${message["text"]}")

    fun extract(sbn: StatusBarNotification): List<Map<String, Any?>> {
        val extras = sbn.notification.extras
        val title = (extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.getCharSequence(Notification.EXTRA_TITLE))?.toString().orEmpty()
        return fromMessagingStyle(sbn, extras, title)
            ?: fromInboxLines(sbn, extras, title)
            ?: listOf(item(sbn, title, mainText(extras), sbn.postTime, "key:${sbn.key}"))
    }

    // SMS apps: one notification per conversation, holding each message.
    @Suppress("DEPRECATION")
    private fun fromMessagingStyle(
        sbn: StatusBarNotification, extras: Bundle, title: String,
    ): List<Map<String, Any?>>? {
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES) ?: return null
        val oldest = sbn.postTime - MAX_MESSAGE_AGE_MS
        return messages.mapNotNull { it as? Bundle }.mapNotNull { message ->
            val time = message.getLong("time").takeIf { it > 0 } ?: sbn.postTime
            val text = message.getCharSequence("text")?.toString() ?: return@mapNotNull null
            if (time < oldest) return@mapNotNull null
            val sender = message.getCharSequence("sender")?.toString()
            item(sbn, title.ifBlank { sender.orEmpty() }, text, time, "msg:$time")
        }.ifEmpty { null }
    }

    // Email apps: several emails summarised as lines.
    private fun fromInboxLines(
        sbn: StatusBarNotification, extras: Bundle, title: String,
    ): List<Map<String, Any?>>? {
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES) ?: return null
        return lines.map { item(sbn, title, it.toString(), sbn.postTime, "key:${sbn.key}") }
            .ifEmpty { null }
    }

    private fun mainText(extras: Bundle): String {
        val body = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)
        val sub = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)
        return listOfNotNull(body, sub).joinToString(" ")
    }

    private fun item(
        sbn: StatusBarNotification, title: String, text: String, time: Long, id: String,
    ): Map<String, Any?> = mapOf(
        "app" to sbn.packageName,
        "title" to title,
        "text" to text,
        "postedAt" to time,
        "messageId" to id,
    )
}
