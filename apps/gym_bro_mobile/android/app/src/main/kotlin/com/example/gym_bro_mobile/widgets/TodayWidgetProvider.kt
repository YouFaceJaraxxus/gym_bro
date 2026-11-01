package com.example.gym_bro_mobile.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.example.gym_bro_mobile.R
import es.antonborri.home_widget.HomeWidgetProvider

/** Today's planned workout (or "Free day") with the streak. */
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val d = GymBroWidgetData(widgetData)
        val muted = context.getColor(R.color.gb_muted)
        val risk = context.getColor(R.color.gb_risk)
        val title = when {
            !d.signedIn -> d.signedOutLabel
            d.isStale || d.workoutName.isEmpty() -> d.staleLabel.ifEmpty { context.getString(R.string.widget_open_app) }
            else -> d.workoutName
        }
        val status = when {
            !d.signedIn || d.isStale -> ""
            d.atRisk && !d.workoutDone -> d.streakRiskLabel
            else -> d.workoutStatus
        }
        val iconColor = context.getColor(if (d.workoutDone) R.color.gb_done else R.color.gb_flame)
        val flame = context.getColor(if (d.streakLit) R.color.gb_flame else R.color.gb_flame_off)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today).apply {
                if (d.todayTitle.isNotEmpty()) setTextViewText(R.id.today_title, d.todayTitle)
                setInt(R.id.today_icon, "setColorFilter", iconColor)
                setInt(R.id.today_flame, "setColorFilter", flame)
                setTextViewText(R.id.today_streak, d.streak.toString())
                setTextViewText(R.id.today_workout, title)
                setTextViewText(R.id.today_status, status)
                setTextColor(R.id.today_status, if (d.atRisk && !d.workoutDone) risk else muted)
                setViewVisibility(R.id.today_status, if (status.isEmpty()) View.GONE else View.VISIBLE)
                setOnClickPendingIntent(R.id.widget_root, GymBroWidgetData.launch(context, "today"))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
