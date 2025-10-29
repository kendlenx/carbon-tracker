package com.kendlenx.carbonstep.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.kendlenx.carbonstep.MainActivity
import com.kendlenx.carbonstep.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class GoalProgressWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_goal_progress)
            val title = widgetData.getString("goal_title", "Goal Progress")
            val text = widgetData.getString("goal_text", "")
            val progress = try { widgetData.getFloat("goal_progress", 0f) } catch (e: ClassCastException) {
                widgetData.getString("goal_progress", "0.0")?.toFloatOrNull() ?: 0f
            }
            val pct = (progress * 100).toInt()
            views.setTextViewText(R.id.txtTitle, title)
            views.setTextViewText(R.id.txtSubtitle, text)
            views.setTextViewText(R.id.txtPercent, "$pct%")
            views.setProgressBar(R.id.progressBar, 100, pct, false)

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
