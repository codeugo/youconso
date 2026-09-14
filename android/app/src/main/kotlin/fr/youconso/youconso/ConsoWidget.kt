package fr.youconso.youconso

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

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
                setTextViewText(R.id.time, widgetData.getString("time", ""))
            }
        }
        views.setOnClickPendingIntent(
            R.id.root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }
}
