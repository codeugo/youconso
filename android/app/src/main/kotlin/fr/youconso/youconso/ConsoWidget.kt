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
        val views = RemoteViews(context.packageName, R.layout.conso_widget).apply {
            setTextViewText(R.id.plan, widgetData.getString("plan", "YouConso"))
            setTextViewText(R.id.used, widgetData.getString("used", "--"))
            setTextViewText(R.id.quota, widgetData.getString("quota", ""))
            setProgressBar(R.id.progress, 100, widgetData.getInt("progress", 0), false)
            setTextViewText(R.id.time, widgetData.getString("time", "Ouvrir l'app pour actualiser"))
            setOnClickPendingIntent(
                R.id.root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
        }
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }
}
