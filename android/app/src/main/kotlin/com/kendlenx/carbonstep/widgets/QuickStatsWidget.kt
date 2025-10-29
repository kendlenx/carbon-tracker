package com.kendlenx.carbonstep.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.kendlenx.carbonstep.MainActivity
import com.kendlenx.carbonstep.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class QuickStatsWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_stats)
            val today = widgetData.getString("stats_today", "0.0")
            val weekly = widgetData.getString("stats_weekly", "0.0")
            val monthly = widgetData.getString("stats_monthly", "0.0")
            views.setTextViewText(R.id.txtToday, "${today} kg")
            views.setTextViewText(R.id.txtWeekly, "${weekly} kg")
            views.setTextViewText(R.id.txtMonthly, "${monthly} kg")

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
