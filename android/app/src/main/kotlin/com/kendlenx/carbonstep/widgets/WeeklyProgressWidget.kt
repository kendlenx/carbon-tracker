package com.kendlenx.carbonstep.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.kendlenx.carbonstep.MainActivity
import com.kendlenx.carbonstep.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class WeeklyProgressWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_weekly_progress)
            val progress = try { widgetData.getFloat("weekly_progress", 0f) } catch (e: ClassCastException) {
                // If stored as double
                widgetData.getString("weekly_progress", "0.0")?.toFloatOrNull() ?: 0f
            }
            val progressPct = (progress * 100).toInt()
            val text = widgetData.getString("weekly_text", "$progressPct%")
            views.setTextViewText(R.id.txtProgress, text)

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
            views.setProgressBar(R.id.progressBar, 100, progressPct, false)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
