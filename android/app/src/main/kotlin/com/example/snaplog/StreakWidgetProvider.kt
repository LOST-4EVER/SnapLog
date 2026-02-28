package com.example.snaplog

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class StreakWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val streakCount = widgetData.getInt("streak_count", 0)
                val lastSnap = widgetData.getString("last_snap_time", "--") ?: "--"
                val isTodayDone = widgetData.getBoolean("is_today_done", false)
                
                setTextViewText(R.id.appwidget_streak_count, streakCount.toString())
                setTextViewText(R.id.appwidget_last_snap, "Last snap: $lastSnap")
                
                if (isTodayDone) {
                    setTextViewText(R.id.appwidget_status, "SNAP COMPLETE")
                    setTextColor(R.id.appwidget_status, android.graphics.Color.parseColor("#4CAF50"))
                } else {
                    setTextViewText(R.id.appwidget_status, "SNAP NEEDED")
                    setTextColor(R.id.appwidget_status, android.graphics.Color.parseColor("#FF5252"))
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
