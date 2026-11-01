package com.example.gym_bro_mobile.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.example.gym_bro_mobile.R
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/** Today's water against the goal: a ring with the percentage, plus the
 *  amounts when the widget is wide enough. */
class WaterWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val d = GymBroWidgetData(widgetData)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, d, appWidgetManager.getAppWidgetOptions(id)))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val d = GymBroWidgetData(HomeWidgetPlugin.getData(context))
        appWidgetManager.updateAppWidget(appWidgetId, build(context, d, newOptions))
    }

    private fun build(context: Context, d: GymBroWidgetData, options: Bundle?): RemoteViews {
        val wide = (options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0) >= 200
        val pct = d.waterPercent
        val caption = when {
            !d.signedIn -> d.signedOutLabel
            d.isStale || d.waterText.isEmpty() -> d.staleLabel.ifEmpty { context.getString(R.string.widget_open_app) }
            else -> d.waterText
        }
        return RemoteViews(context.packageName, R.layout.widget_water).apply {
            setProgressBar(R.id.water_ring, 100, pct.coerceIn(0, 100), false)
            setTextViewText(R.id.water_pct, "$pct%")
            setViewVisibility(R.id.water_details, if (wide) View.VISIBLE else View.GONE)
            if (d.waterTitle.isNotEmpty()) setTextViewText(R.id.water_title, d.waterTitle)
            setTextViewText(R.id.water_text, caption)
            setOnClickPendingIntent(R.id.widget_root, GymBroWidgetData.launch(context, "water"))
        }
    }
}
