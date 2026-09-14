package fr.youconso.youconso

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ConsoWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val value = widgetData.getString("value", null)
        val views = if (value == null) {
            RemoteViews(context.packageName, R.layout.conso_widget_empty)
        } else {
            RemoteViews(context.packageName, R.layout.conso_widget).apply {
                setTextViewText(R.id.title, widgetData.getString("title", ""))
                setTextViewText(R.id.value, value)
                setProgressBar(R.id.progress, 100, widgetData.getInt("progress", 0), false)
            }
        }
        views.setOnClickPendingIntent(
            R.id.root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }
}
