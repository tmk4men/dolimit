// 配置先: android/app/src/main/kotlin/<applicationId のパス>/DoLimitWidgetProvider.kt
// package 行を実際の applicationId（例: com.example.dolimit）に合わせること。
package com.example.dolimit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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
                val cleared = count == 0 && titles.isBlank()

                // TODAY が空なら「決着」状態、そうでなければ件数＋タスク名を出す。
                if (cleared) {
                    setViewVisibility(R.id.state_normal, View.GONE)
                    setViewVisibility(R.id.state_cleared, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.state_normal, View.VISIBLE)
                    setViewVisibility(R.id.state_cleared, View.GONE)
                    setTextViewText(R.id.widget_count, count.toString())
                    setTextViewText(R.id.widget_titles, titles)
                }

                // タップでアプリを起動して TODAY を開く。Dart 側（app.dart）が
                // dolimit://today を受け取ってタブを切り替える。MainActivity は
                // 本ファイルと同じ applicationId パッケージにある想定。
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dolimit://today")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
