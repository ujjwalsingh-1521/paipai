package com.expense.expense_tracker

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        BackupChannelHandler(applicationContext, messenger)
        AppChannel.attach(this, messenger)
        AppChannel.onLaunchIntent(intent)
    }

    // A notification was tapped while the app was already open.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        AppChannel.onLaunchIntent(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        AppChannel.onPermissionResult(this, requestCode, grantResults)
    }

    override fun onDestroy() {
        AppChannel.detach(this)
        super.onDestroy()
    }
}
