package com.example.gym_bro_mobile.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.example.gym_bro_mobile.R
import es.antonborri.home_widget.HomeWidgetProvider

/** Flame, streak count, badge, and "train today" when the streak is at risk. */
class StreakWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val d = GymBroWidgetData(widgetData)
        val flame = context.getColor(if (d.streakLit) R.color.gb_flame else R.color.gb_flame_off)
        val muted = context.getColor(R.color.gb_muted)
        val risk = context.getColor(R.color.gb_risk)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_streak).apply {
                setInt(R.id.streak_flame, "setColorFilter", flame)
                if (d.signedIn) {
                    setTextViewText(R.id.streak_count, d.streak.toString())
                    setViewVisibility(R.id.streak_count, View.VISIBLE)
                    setTextViewText(
                        R.id.streak_label,
                        if (d.atRisk) d.streakRiskLabel else d.streakLabel.ifEmpty { context.getString(R.string.widget_streak_label) },
                    )
                    setTextColor(R.id.streak_label, if (d.atRisk) risk else muted)
                } else {
                    setViewVisibility(R.id.streak_count, View.GONE)
                    setTextViewText(R.id.streak_label, d.signedOutLabel.ifEmpty { context.getString(R.string.widget_open_app) })
                    setTextColor(R.id.streak_label, muted)
                }
                setTextViewText(R.id.streak_tier, d.streakTier)
                setViewVisibility(R.id.streak_tier, if (d.signedIn && d.streakTier.isNotEmpty()) View.VISIBLE else View.GONE)
                setOnClickPendingIntent(R.id.widget_root, GymBroWidgetData.launch(context, "streak"))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
