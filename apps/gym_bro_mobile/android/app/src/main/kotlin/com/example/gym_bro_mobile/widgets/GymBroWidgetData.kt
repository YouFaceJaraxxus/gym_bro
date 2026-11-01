package com.example.gym_bro_mobile.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import com.example.gym_bro_mobile.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.time.LocalDate

/**
 * What the app last wrote for the widgets (lib/services/home_widget_service.dart),
 * read from home_widget's SharedPreferences. Labels arrive already translated.
 */
class GymBroWidgetData(prefs: SharedPreferences) {
    private val all = prefs.all

    private fun str(key: String): String = all[key] as? String ?: ""
    private fun int(key: String): Int = (all[key] as? Number)?.toInt() ?: 0
    private fun bool(key: String): Boolean = all[key] as? Boolean ?: false

    val signedIn = bool("gb_signed_in")
    val day = str("gb_day")

    val streak = int("gb_streak")
    val streakLit = bool("gb_streak_lit")
    val streakRisk = bool("gb_streak_risk")
    val streakTier = str("gb_streak_tier")
    val streakLabel = str("gb_streak_label")
    val streakRiskLabel = str("gb_streak_risk_label")

    val waterMl = int("gb_water_ml")
    val waterGoalMl = int("gb_water_goal_ml")
    val waterTitle = str("gb_water_title")
    val waterText = str("gb_water_text")

    val todayTitle = str("gb_today_title")
    val workoutName = str("gb_workout_name")
    val workoutStatus = str("gb_workout_status")
    val workoutDone = bool("gb_workout_done")
    val workoutFree = bool("gb_workout_free")

    val signedOutLabel = str("gb_signed_out_label")
    val staleLabel = str("gb_stale_label")

    /** Written on an earlier day: today's water and plan aren't known yet. */
    val isStale: Boolean get() = day != LocalDate.now().toString()

    val atRisk: Boolean get() = streakRisk && !isStale

    val waterPercent: Int
        get() = if (waterGoalMl <= 0 || isStale) 0 else Math.round(waterMl * 100f / waterGoalMl)

    companion object {
        /** Opens the app on [page] (see HomeWidgetService.openLink). */
        fun launch(context: Context, page: String): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("gymbroo://widget/$page?homeWidget"),
            )
    }
}
