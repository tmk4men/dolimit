// 配置先: android/app/src/main/kotlin/<applicationId のパス>/DoLimitWidgetProvider.kt
// package 行を実際の applicationId（例: com.example.dolimit）に合わせること。
package com.example.dolimit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DoLimitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.dolimit_widget).apply {
                val count = widgetData.getInt("today_count", 0)
                val titles = widgetData.getString("today_titles", "") ?: ""
                setTextViewText(R.id.widget_count, count.toString())
                setTextViewText(
                    R.id.widget_titles,
                    if (titles.isBlank()) "TODAYは空です" else titles
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
