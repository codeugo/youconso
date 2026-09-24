package fr.youconso.youconso

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.text.format.DateUtils
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ConsoWidget : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val fromSystem = intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE &&
            !intent.getBooleanExtra(HomeWidgetPlugin.TRIGGERED_FROM_HOME_WIDGET, false)
        if (fromSystem) {
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("youconso://refresh")).send()
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val used = widgetData.getString("used", null)
        val views = if (used == null) {
            RemoteViews(context.packageName, R.layout.conso_widget_empty)
        } else {
            RemoteViews(context.packageName, R.layout.conso_widget).apply {
                setTextViewText(R.id.title, widgetData.getString("title", ""))
                setTextViewText(R.id.used, used)
                setTextViewText(R.id.quota, widgetData.getString("quota", ""))
                setProgressBar(R.id.progress, 100, widgetData.getInt("progress", 0), false)
                setUpdatedAt(widgetData.getLong("updatedAt", 0L))
            }
        }
        views.setOnClickPendingIntent(
            R.id.root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

    /**
     * "Actualisé à 9:41" the same day, then "Actualisé le 21/09" and a hint,
     * since the widget never logs in again by itself. Recomputed on each
     * periodic update, so it changes at midnight without the app.
     */
    private fun RemoteViews.setUpdatedAt(millis: Long) {
        val today = DateUtils.isToday(millis)
        val time = when {
            millis == 0L -> null // Data written before this key existed.
            today -> "Actualisé à " + format("H:mm", millis)
            else -> "Actualisé le " + format("dd/MM", millis)
        }
        setTextViewText(R.id.time, time)
        setViewVisibility(R.id.time, if (time == null) View.GONE else View.VISIBLE)
        setViewVisibility(R.id.hint, if (today) View.GONE else View.VISIBLE)
    }

    private fun format(pattern: String, millis: Long) =
        SimpleDateFormat(pattern, Locale.FRANCE).format(Date(millis))
}
