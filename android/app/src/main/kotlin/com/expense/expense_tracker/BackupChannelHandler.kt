package com.expense.expense_tracker

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Saves backup files to Downloads/PaiPai through MediaStore. Files there are
 * not removed when the app is uninstalled, and no storage permission is
 * needed on Android 10+ for files the app creates itself.
 */
class BackupChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.expense.expense_tracker/backup"
        private const val RELATIVE_DIR = "Download/PaiPai"
    }

    // Single thread: file IO stays off the UI thread and saves never overlap.
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "save" -> runInBackground(result) {
                save(call.argument<String>("fileName")!!, call.argument<String>("content")!!)
            }
            "prune" -> runInBackground(result) {
                prune(call.argument<String>("prefix")!!, call.argument<Int>("keep")!!)
            }
            else -> result.notImplemented()
        }
    }

    private fun isSupported() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    private fun runInBackground(result: MethodChannel.Result, work: () -> Unit) {
        if (!isSupported()) {
            result.error("UNSUPPORTED", "Saving to Downloads needs Android 10 or newer", null)
            return
        }
        io.execute {
            try {
                work()
                main.post { result.success(null) }
            } catch (e: Exception) {
                main.post { result.error("BACKUP_IO", e.message ?: e.toString(), null) }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun save(fileName: String, content: String) {
        val resolver = context.contentResolver
        val existing = findOwnCopy(fileName)
        val uri = existing ?: createPendingFile(fileName)
        resolver.openOutputStream(uri, "wt")?.use { it.write(content.toByteArray()) }
            ?: throw IOException("Could not write $fileName")
        if (existing == null) {
            // Publish the file only once it is fully written.
            resolver.update(uri, ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }, null, null)
        }
    }

    /**
     * This install's copy of [fileName]. After a reinstall the old file is no
     * longer ours, so Android names our copy "name (1).json"; reuse that copy
     * instead of creating "(2)", "(3)"... on every save that day.
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun findOwnCopy(fileName: String): Uri? {
        val base = fileName.substringBeforeLast('.')
        val ext = fileName.substringAfterLast('.', "")
        return (ownFiles(fileName, exact = true) + ownFiles("$base (%).$ext", exact = false))
            .firstOrNull()?.first
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun createPendingFile(fileName: String): Uri {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
            put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE_DIR)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        return context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("Could not create $fileName in Downloads")
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun prune(prefix: String, keep: Int) {
        ownFiles("$prefix%", exact = false)
            .sortedByDescending { it.second }
            .drop(keep)
            .forEach { context.contentResolver.delete(it.first, null, null) }
    }

    /**
     * Files in Downloads/PaiPai named [name] (or matching it as a LIKE pattern
     * when not [exact]), as (uri, name). MediaStore only returns files this
     * install created, so files left by a previous install are never touched.
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun ownFiles(name: String, exact: Boolean): List<Pair<Uri, String>> {
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME)
        val nameOperator = if (exact) "=" else "LIKE"
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND " +
            "${MediaStore.MediaColumns.DISPLAY_NAME} $nameOperator ?"
        val args = arrayOf("$RELATIVE_DIR%", name)
        val files = mutableListOf<Pair<Uri, String>>()
        context.contentResolver.query(collection, projection, selection, args, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val uri = Uri.withAppendedPath(collection, cursor.getLong(0).toString())
                files.add(uri to cursor.getString(1))
            }
        }
        return files
    }
}
