package com.kendlenx.carbonstep.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.kendlenx.carbonstep.MainActivity
import com.kendlenx.carbonstep.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LevelProgressWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_level_progress)
            val level = widgetData.getInt("current_level", 1)
            val rank = widgetData.getString("current_rank", "")
            val progress = try { widgetData.getFloat("level_progress", 0f) } catch (e: ClassCastException) {
                widgetData.getString("level_progress", "0.0")?.toFloatOrNull() ?: 0f
            }
            val pct = (progress * 100).toInt()
            val toNext = widgetData.getInt("points_to_next", 0)

            views.setTextViewText(R.id.txtHeader, "Level $level • $rank")
            views.setTextViewText(R.id.txtPercent, "$pct% • $toNext XP")
            views.setProgressBar(R.id.progressBar, 100, pct, false)

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
