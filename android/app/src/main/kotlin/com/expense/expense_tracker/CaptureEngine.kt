package com.expense.expense_tracker

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * A headless Flutter engine that runs `paymentCaptureMain` (lib/main.dart),
 * so captured payments are parsed, de-duplicated and saved by the same
 * Dart code as the app, even while the app is closed. Started on first use
 * and kept for the life of the process.
 */
object CaptureEngine {
    const val CHANNEL = "com.expense.expense_tracker/capture"
    private const val ENTRYPOINT = "paymentCaptureMain"

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var dartReady = false

    private class Event(val method: String, val arguments: Any?, val onDone: ((Boolean, Any?) -> Unit)?)

    // Events that arrive before the Dart side has set up its handler.
    private val waiting = ArrayDeque<Event>()

    /**
     * [onDone] runs on the main thread once Dart has handled the event
     * (true, with Dart's reply) or failed (false).
     */
    fun deliver(context: Context, method: String, arguments: Any?, onDone: ((Boolean, Any?) -> Unit)? = null) {
        main.post {
            ensureStarted(context.applicationContext)
            val event = Event(method, arguments, onDone)
            if (dartReady) send(event) else waiting.addLast(event)
        }
    }

    private fun send(event: Event) {
        val channel = channel
        if (channel == null) {
            event.onDone?.invoke(false, null)
            return
        }
        channel.invokeMethod(event.method, event.arguments, object : MethodChannel.Result {
            override fun success(result: Any?) { event.onDone?.invoke(true, result) }
            override fun error(code: String, message: String?, details: Any?) { event.onDone?.invoke(false, null) }
            override fun notImplemented() { event.onDone?.invoke(false, null) }
        })
    }

    private fun ensureStarted(context: Context) {
        if (engine != null) return
        Log.i(PaymentNotificationListener.TAG, "starting capture engine")
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationComplete(context, null)
        val newEngine = FlutterEngine(context)
        channel = MethodChannel(newEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result -> onCall(context, call, result) }
        }
        engine = newEngine
        newEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
        )
    }

    private fun onCall(context: Context, call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "backgroundReady") {
            Log.i(PaymentNotificationListener.TAG, "capture engine ready, ${waiting.size} waiting")
            dartReady = true
            while (waiting.isNotEmpty()) send(waiting.removeFirst())
            result.success(null)
        } else if (!AlertNotifier.handle(context, call, result) && !SmsCapture.handle(context, call, result)) {
            result.notImplemented()
        }
    }
}
