package com.expense.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import kotlin.math.max
import kotlin.math.min

/**
 * The four home-screen widgets. The Dart side (lib/services/widgets/) sends
 * a ready-to-show snapshot whenever data changes ("updateWidgets" on the
 * capture channel); this object stores it and draws every widget from it.
 * Buttons reuse the notification's actions: a category taps straight into
 * AlertActionReceiver, More opens QuickPickActivity.
 */
object PaiPaiWidgets {
    private const val PREFS = "paipai_widgets"
    private const val KEY_SNAPSHOT = "snapshot"
    private const val KEY_INDEX = "label_index"
    private const val KEY_HANDLED = "handled_pending"

    /** How long a tapped payment stays hidden if no fresh snapshot confirms it. */
    private const val HANDLED_TTL_MS = 5 * 60_000L
    const val ACTION_NEXT = "com.expense.expense_tracker.widget.NEXT"
    const val EXTRA_OPEN_SCREEN = "open_screen"

    private val providers = listOf(
        LabelWidget::class.java, PaceWidget::class.java,
        CategoriesWidget::class.java, QuickAddWidget::class.java,
    )

    /**
     * commit(), not apply(): the capture engine's process can be stopped
     * right after this, and a lost write would bring back the old snapshot.
     */
    fun update(context: Context, json: String?) {
        prefs(context).edit().putString(KEY_SNAPSHOT, json).commit()
        forgetConfirmed(context, json)
        refreshAll(context)
    }

    /**
     * A category was tapped (on the widget or the notification): hide that
     * payment right away, before the save finishes. Returns its title
     * ("₹340 · Swiggy") for the confirmation, if the widget knows it.
     */
    fun markHandled(context: Context, pendingId: Int): String? {
        val handled = handledIds(context) + (pendingId to System.currentTimeMillis())
        prefs(context).edit().putString(KEY_HANDLED, encode(handled)).commit()
        redrawLabelNow(context)
        return findPending(context, pendingId)?.optString("title")?.replace(" paid · ", " · ")
    }

    /**
     * Draws the Label widgets right here instead of via an update broadcast:
     * the capture engine starts next on this same thread and would hold that
     * broadcast back for seconds.
     */
    private fun redrawLabelNow(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val label = LabelWidget()
        manager.getAppWidgetIds(ComponentName(context, LabelWidget::class.java)).forEach { label.render(context, manager, it) }
    }

    /** Payments hidden because they were just labelled, still awaiting a fresh snapshot. */
    fun hiddenIds(context: Context): Set<Int> {
        val now = System.currentTimeMillis()
        return handledIds(context).filterValues { now - it < HANDLED_TTL_MS }.keys
    }

    /** A snapshot without a hidden payment proves it was saved; stop hiding it. */
    private fun forgetConfirmed(context: Context, json: String?) {
        val stillPending = pendingIds(json?.let { runCatching { JSONObject(it) }.getOrNull() })
        val handled = handledIds(context).filterKeys { it in stillPending }
        prefs(context).edit().putString(KEY_HANDLED, encode(handled)).commit()
    }

    private fun findPending(context: Context, id: Int): JSONObject? {
        val pending = snapshot(context)?.optJSONArray("pending") ?: return null
        return (0 until pending.length()).map { pending.getJSONObject(it) }.firstOrNull { it.optInt("id") == id }
    }

    private fun pendingIds(snapshot: JSONObject?): Set<Int> {
        val pending = snapshot?.optJSONArray("pending") ?: return emptySet()
        return (0 until pending.length()).map { pending.getJSONObject(it).optInt("id") }.toSet()
    }

    /** Stored as "id:millis,id:millis". */
    private fun handledIds(context: Context): Map<Int, Long> =
        prefs(context).getString(KEY_HANDLED, "").orEmpty().split(',').mapNotNull { entry ->
            val (id, at) = entry.split(':').takeIf { it.size == 2 } ?: return@mapNotNull null
            (id.toIntOrNull() ?: return@mapNotNull null) to (at.toLongOrNull() ?: return@mapNotNull null)
        }.toMap()

    private fun encode(handled: Map<Int, Long>) = handled.entries.joinToString(",") { "${it.key}:${it.value}" }

    /** The waiting payments the Label widget shows: the snapshot's, minus those just labelled. */
    fun visiblePending(context: Context): JSONArray {
        val all = snapshot(context)?.optJSONArray("pending") ?: return JSONArray()
        val hidden = hiddenIds(context)
        return JSONArray((0 until all.length()).map { all.getJSONObject(it) }.filter { it.optInt("id") !in hidden })
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isNotEmpty()) context.sendBroadcast(updateIntent(context, provider, ids))
        }
    }

    private fun updateIntent(context: Context, provider: Class<*>, ids: IntArray) =
        Intent(context, provider)
            .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            .putExtra(EXTRA_FROM_APP, true)

    /** Set on updates PaiPai sends itself, so they don't ask Dart again. */
    const val EXTRA_FROM_APP = "from_paipai"

    fun snapshot(context: Context): JSONObject? =
        prefs(context).getString(KEY_SNAPSHOT, null)?.let { runCatching { JSONObject(it) }.getOrNull() }

    /** Old snapshots (none yet, or from last month) get recomputed by Dart. */
    fun isStale(snapshot: JSONObject?): Boolean {
        if (snapshot == null) return true
        val now = Calendar.getInstance()
        return snapshot.optString("monthKey") != "${now.get(Calendar.YEAR)}-${now.get(Calendar.MONTH) + 1}"
    }

    fun requestFresh(context: Context) = CaptureEngine.deliver(context, "refreshWidgets", null)

    fun labelIndex(context: Context) = prefs(context).getInt(KEY_INDEX, 0)

    fun setLabelIndex(context: Context, index: Int) =
        prefs(context).edit().putInt(KEY_INDEX, index).commit()

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun openInsights(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN_SCREEN, "insights")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(context, 9001, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(context, 9002, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

/** Common to all four: draw on every update and on resize. */
abstract class PaiPaiWidgetProvider : AppWidgetProvider() {
    abstract fun render(context: Context, manager: AppWidgetManager, id: Int)

    /** Whether a scheduled update should ask Dart for fresh numbers. */
    open fun refreshesOnSchedule() = false

    override fun onReceive(context: Context, intent: Intent) {
        fromApp = intent.getBooleanExtra(PaiPaiWidgets.EXTRA_FROM_APP, false)
        super.onReceive(context, intent)
    }

    private var fromApp = false

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
        val snapshot = PaiPaiWidgets.snapshot(context)
        if (!fromApp && (refreshesOnSchedule() || PaiPaiWidgets.isStale(snapshot))) {
            PaiPaiWidgets.requestFresh(context)
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        render(context, manager, id)
    }

    /** Widget size in pixels (portrait: min width, max height). */
    protected fun sizePx(context: Context, manager: AppWidgetManager, id: Int): Pair<Int, Int> {
        val options = manager.getAppWidgetOptions(id)
        val density = context.resources.displayMetrics.density
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 140)
        return (width * density).toInt() to (height * density).toInt()
    }

    protected fun color(context: Context, res: Int) = context.getColor(res)
}

/** "₹340 paid · Swiggy  [Food] [Groceries] [More]", stepping through all waiting. */
class LabelWidget : PaiPaiWidgetProvider() {
    override fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_label)
        val pending = PaiPaiWidgets.visiblePending(context)
        if (pending.length() == 0) {
            showEmpty(views)
            views.setOnClickPendingIntent(R.id.widget_root, PaiPaiWidgets.openApp(context))
        } else {
            showPayment(context, views, pending)
        }
        manager.updateAppWidget(id, views)
    }

    private fun showEmpty(views: RemoteViews) {
        views.setViewVisibility(R.id.label_payment, View.GONE)
        views.setViewVisibility(R.id.label_buttons, View.GONE)
        views.setViewVisibility(R.id.label_empty, View.VISIBLE)
    }

    private fun showPayment(context: Context, views: RemoteViews, pending: JSONArray) {
        val index = PaiPaiWidgets.labelIndex(context).coerceIn(0, pending.length() - 1)
        val payment = pending.getJSONObject(index)
        val pendingId = payment.getInt("id")
        views.setViewVisibility(R.id.label_payment, View.VISIBLE)
        views.setViewVisibility(R.id.label_buttons, View.VISIBLE)
        views.setViewVisibility(R.id.label_empty, View.GONE)
        views.setTextViewText(R.id.label_title, payment.optString("title"))
        views.setTextViewText(R.id.label_time, payment.optString("time"))

        val more = pending.length() > 1
        views.setViewVisibility(R.id.label_next, if (more) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.label_next, "${index + 1}/${pending.length()} ›")
        views.setOnClickPendingIntent(R.id.label_next, nextIntent(context))

        val buttons = payment.optJSONArray("buttons") ?: JSONArray()
        listOf(R.id.label_button_1, R.id.label_button_2).forEachIndexed { i, view ->
            val category = buttons.optString(i, "")
            views.setViewVisibility(view, if (category.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(view, category)
            if (category.isNotEmpty()) {
                views.setOnClickPendingIntent(view, AlertNotifier.categoryIntent(context, pendingId, category, i, fromWidget = true))
            }
        }
        val card = QuickPickActivity.intent(context, pendingId)
        views.setOnClickPendingIntent(R.id.label_more, card)
        views.setOnClickPendingIntent(R.id.label_open, card)
    }

    private fun nextIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).setAction(PaiPaiWidgets.ACTION_NEXT)
        return PendingIntent.getBroadcast(context, 9003, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

/** "1 of 3 ›" on the Label payments widget. */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != PaiPaiWidgets.ACTION_NEXT) return
        val count = PaiPaiWidgets.visiblePending(context).length()
        if (count == 0) return
        PaiPaiWidgets.setLabelIndex(context, (PaiPaiWidgets.labelIndex(context) + 1) % count)
        PaiPaiWidgets.refreshAll(context)
    }
}

/** This month's running total against last month's, like Home's chart. */
class PaceWidget : PaiPaiWidgetProvider() {
    override fun refreshesOnSchedule() = true

    override fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_pace)
        val snapshot = PaiPaiWidgets.snapshot(context)
        if (snapshot != null) {
            views.setTextViewText(R.id.pace_month, "${snapshot.optString("month")} so far")
            views.setTextViewText(R.id.pace_spent, snapshot.optString("spent"))
            views.setTextViewText(R.id.pace_text, snapshot.optString("pace"))
            val budget = snapshot.optString("budget")
            views.setTextViewText(R.id.pace_budget, budget)
            views.setViewVisibility(R.id.pace_budget, if (budget.isEmpty()) View.GONE else View.VISIBLE)
            setLabels(views, snapshot.optJSONArray("axisLabels"), R.id.pace_axis_top, R.id.pace_axis_mid, R.id.pace_axis_zero)
            setLabels(views, snapshot.optJSONArray("dayLabels"), R.id.pace_day_first, R.id.pace_day_mid, R.id.pace_day_last)
            val (width, height) = sizePx(context, manager, id)
            val density = context.resources.displayMetrics.density
            // The chart gets what's left after the text, the scale and padding.
            val axisWidth = context.resources.getDimensionPixelSize(R.dimen.widget_axis_width)
            val chartWidth = max(1, width - (24 * density).toInt() - axisWidth)
            val budgetLine = if (budget.isEmpty()) 0 else 15
            val chartHeight = (height - ((104 + budgetLine) * density).toInt()).coerceIn((32 * density).toInt(), (220 * density).toInt())
            views.setImageViewBitmap(R.id.pace_chart, drawPace(context, snapshot, chartWidth, chartHeight))
            tintChart(context, views)
        }
        views.setOnClickPendingIntent(R.id.widget_root, PaiPaiWidgets.openInsights(context))
        manager.updateAppWidget(id, views)
    }

    /**
     * The chart is drawn in white with varying transparency and coloured by a
     * tint, so it follows light/dark mode (Android 12+ switches the tint by
     * itself; older phones get the current mode's colour).
     */
    private fun tintChart(context: Context, views: RemoteViews) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorInt(R.id.pace_chart, "setColorFilter",
                themed(context, Configuration.UI_MODE_NIGHT_NO), themed(context, Configuration.UI_MODE_NIGHT_YES))
        } else {
            views.setInt(R.id.pace_chart, "setColorFilter", color(context, R.color.widget_primary))
        }
    }

    private fun themed(context: Context, night: Int): Int {
        val config = Configuration(context.resources.configuration).apply {
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or night
        }
        return context.createConfigurationContext(config).getColor(R.color.widget_primary)
    }

    private fun setLabels(views: RemoteViews, labels: JSONArray?, vararg ids: Int) =
        ids.forEachIndexed { i, id -> views.setTextViewText(id, labels?.optString(i, "") ?: "") }

    private fun drawPace(context: Context, snapshot: JSONObject, width: Int, height: Int): Bitmap {
        val thisMonth = doubles(snapshot.optJSONArray("thisMonth"))
        val lastMonth = doubles(snapshot.optJSONArray("lastMonth"))
        val days = max(2, max(snapshot.optInt("days", 30), lastMonth.size))
        // The scale's round top from Dart, so the labels beside the chart match.
        val top = snapshot.optDouble("axisTop", max(1.0, (thisMonth + lastMonth).maxOrNull() ?: 1.0))
        val density = context.resources.displayMetrics.density
        // Half a label's height, so the scale labels sit on the top and bottom lines.
        val pad = 6 * density
        val bitmap = Bitmap.createBitmap(max(1, width), max(1, height), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val edge = 2 * density // room for the line's round cap at day 1
        fun x(day: Int) = edge + (day - 1f) / (days - 1f) * (width - edge - pad)
        fun y(value: Double) = (height - pad - value / top * (height - 2 * pad)).toFloat()

        val base = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; alpha = 60; strokeWidth = density }
        canvas.drawLine(0f, height - pad, width.toFloat(), height - pad, base)
        val grid = Paint(base).apply { alpha = 28 }
        for (value in listOf(top, top / 2)) canvas.drawLine(0f, y(value), width.toFloat(), y(value), grid)

        if (lastMonth.isNotEmpty()) {
            val dashed = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE; alpha = 110
                style = Paint.Style.STROKE; strokeWidth = 2 * density
                pathEffect = DashPathEffect(floatArrayOf(5 * density, 5 * density), 0f)
            }
            canvas.drawPath(line(lastMonth, ::x, ::y), dashed)
        }
        if (thisMonth.isNotEmpty()) drawThisMonth(context, canvas, thisMonth, ::x, ::y, height - pad, density)
        return bitmap
    }

    private fun drawThisMonth(
        context: Context, canvas: Canvas, values: List<Double>,
        x: (Int) -> Float, y: (Double) -> Float, baseline: Float, density: Float,
    ) {
        val primary = Color.WHITE // coloured by tintChart
        val path = line(values, x, y)
        val fill = Path(path).apply { lineTo(x(values.size), baseline); lineTo(x(1), baseline); close() }
        canvas.drawPath(fill, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = primary; alpha = 50 })
        canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = primary; style = Paint.Style.STROKE; strokeWidth = 3 * density
            strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
        })
        canvas.drawCircle(x(values.size), y(values.last()), 4.5f * density, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = primary })
    }

    private fun line(values: List<Double>, x: (Int) -> Float, y: (Double) -> Float) = Path().apply {
        values.forEachIndexed { i, v -> if (i == 0) moveTo(x(1), y(v)) else lineTo(x(i + 1), y(v)) }
        if (values.size == 1) lineTo(x(1) + 1, y(values[0]))
    }

    private fun doubles(array: JSONArray?) = List(array?.length() ?: 0) { array!!.optDouble(it, 0.0) }
}

/** This month's categories: share bar plus the top ones that fit. */
class CategoriesWidget : PaiPaiWidgetProvider() {
    override fun refreshesOnSchedule() = true

    private val rows = listOf(
        Row(R.id.cat_row_1, R.id.cat_dot_1, R.id.cat_name_1, R.id.cat_amount_1, R.id.cat_percent_1),
        Row(R.id.cat_row_2, R.id.cat_dot_2, R.id.cat_name_2, R.id.cat_amount_2, R.id.cat_percent_2),
        Row(R.id.cat_row_3, R.id.cat_dot_3, R.id.cat_name_3, R.id.cat_amount_3, R.id.cat_percent_3),
        Row(R.id.cat_row_4, R.id.cat_dot_4, R.id.cat_name_4, R.id.cat_amount_4, R.id.cat_percent_4),
        Row(R.id.cat_row_5, R.id.cat_dot_5, R.id.cat_name_5, R.id.cat_amount_5, R.id.cat_percent_5),
        Row(R.id.cat_row_6, R.id.cat_dot_6, R.id.cat_name_6, R.id.cat_amount_6, R.id.cat_percent_6),
    )

    private data class Row(val row: Int, val dot: Int, val name: Int, val amount: Int, val percent: Int)

    override fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_categories)
        val snapshot = PaiPaiWidgets.snapshot(context)
        val categories = snapshot?.optJSONArray("categories") ?: JSONArray()
        views.setTextViewText(R.id.cat_month, snapshot?.optString("month") ?: "")
        views.setTextViewText(R.id.cat_total, snapshot?.optString("spent") ?: "")
        val (width, height) = sizePx(context, manager, id)
        views.setImageViewBitmap(R.id.cat_bar, drawShares(context, categories, max(1, width), context.resources.displayMetrics.density))
        views.setViewVisibility(R.id.cat_empty, if (categories.length() == 0) View.VISIBLE else View.GONE)
        val widthDp = width / context.resources.displayMetrics.density
        fillRows(context, views, snapshot, categories, fittingRows(context, height), wide = widthDp >= 250)
        showPercents(views, width / context.resources.displayMetrics.density >= 170)
        views.setOnClickPendingIntent(R.id.widget_root, PaiPaiWidgets.openInsights(context))
        manager.updateAppWidget(id, views)
    }

    /** Rows of 22dp under the header and bar. */
    private fun fittingRows(context: Context, heightPx: Int): Int {
        val heightDp = heightPx / context.resources.displayMetrics.density
        return ((heightDp - 60) / 22).toInt().coerceIn(1, rows.size)
    }

    /** A 2-column widget is too narrow for name, amount and share; keep the amount. */
    private fun showPercents(views: RemoteViews, show: Boolean) {
        rows.forEach { views.setViewVisibility(it.percent, if (show) View.VISIBLE else View.GONE) }
    }

    /** When categories don't fit, the last row sums up the rest ("3 more"). */
    private fun fillRows(
        context: Context, views: RemoteViews, snapshot: JSONObject?, categories: JSONArray, fit: Int, wide: Boolean,
    ) {
        val folded = categories.length() > fit
        val shown = if (folded) fit - 1 else min(fit, categories.length())
        rows.forEachIndexed { i, row ->
            val item = when {
                i < shown -> categories.getJSONObject(i)
                folded && i == shown -> snapshot?.optJSONArray("more")?.optJSONObject(shown)
                else -> null
            }
            views.setViewVisibility(row.row, if (item == null) View.GONE else View.VISIBLE)
            if (item != null) {
                views.setTextColor(row.dot, if (item.has("color")) item.getInt("color") else color(context, R.color.widget_muted))
                views.setTextViewText(row.name, item.optString("name"))
                // "₹1,080 / ₹1.5K" only fits beside the name on a wide widget.
                val budget = item.optString("budget")
                val amount = item.optString("amount")
                views.setTextViewText(row.amount, if (budget.isNotEmpty() && wide) "$amount / $budget" else amount)
                views.setTextViewText(row.percent, item.optString("percent"))
            }
        }
    }

    private fun drawShares(context: Context, categories: JSONArray, width: Int, density: Float): Bitmap {
        val height = (8 * density).toInt()
        val bitmap = Bitmap.createBitmap(width, max(1, height), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = height / 2f
        val clip = Path().apply { addRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, Path.Direction.CW) }
        canvas.clipPath(clip)
        if (categories.length() == 0) {
            canvas.drawColor(color(context, R.color.widget_track))
            return bitmap
        }
        val gap = 2 * density
        val usable = width - gap * (categories.length() - 1)
        var left = 0f
        for (i in 0 until categories.length()) {
            val item = categories.getJSONObject(i)
            // Tiny shares still get a sliver so every category shows up.
            val segment = max(3 * density, (item.optDouble("share") * usable).toFloat())
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = item.getInt("color") }
            canvas.drawRect(left, 0f, min(width.toFloat(), left + segment), height.toFloat(), paint)
            left += segment + gap
        }
        return bitmap
    }
}

/** A "+" that opens the add sheet over the home screen. */
class QuickAddWidget : PaiPaiWidgetProvider() {
    override fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
        views.setOnClickPendingIntent(R.id.widget_root, QuickPickActivity.addIntent(context))
        manager.updateAppWidget(id, views)
    }
}
