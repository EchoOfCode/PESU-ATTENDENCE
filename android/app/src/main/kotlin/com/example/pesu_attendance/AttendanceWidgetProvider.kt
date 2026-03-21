package com.example.pesu_attendance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import org.json.JSONArray

class AttendanceWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.attendance_widget)

            try {
                val prefs = context.getSharedPreferences(
                    "HomeWidgetPreferences", Context.MODE_PRIVATE
                )
                val jsonString = prefs.getString("widgetDataJson", null)
                
                // Read flutter prefs for theme
                val flutterPrefs = context.getSharedPreferences(
                    "FlutterSharedPreferences", Context.MODE_PRIVATE
                )
                val appTheme = flutterPrefs.getString("flutter.app_theme", "default")
                
                // Define theme colors
                var bgColorResource = R.drawable.widget_background
                var textColor = 0xFFFFFFFF.toInt()
                var secTextColor = 0xFF9AA0A6.toInt()
                var safeColor = 0xFF81C995.toInt()
                var warningColor = 0xFFFDE293.toInt()
                var dangerColor = 0xFFF28B82.toInt()
                var dividerColor = 0x1AFFFFFF.toInt()

                if (appTheme == "funny") {
                    bgColorResource = R.drawable.widget_bg_funny
                    textColor = 0xFF000000.toInt()
                    secTextColor = 0xFF444444.toInt()
                    safeColor = 0xFF10B981.toInt()
                    warningColor = 0xFFF59E0B.toInt()
                    dangerColor = 0xFFDC2626.toInt()
                    dividerColor = 0x22000000.toInt()
                } else if (appTheme == "cute") {
                    bgColorResource = R.drawable.widget_bg_cute
                    textColor = 0xFF5D3A9B.toInt()
                    secTextColor = 0xFF9B7EBD.toInt()
                    safeColor = 0xFF5ED5A8.toInt()
                    warningColor = 0xFFFFB26B.toInt()
                    dangerColor = 0xFFFF9AA2.toInt()
                    dividerColor = 0x225D3A9B.toInt()
                }

                // Apply overall background
                views.setInt(R.id.widget_subject_list, "setBackgroundResource", bgColorResource)

                // Apply text colors to main views
                views.setTextColor(R.id.widget_header_title, textColor)
                views.setTextColor(R.id.legend_text_good, secTextColor)
                views.setTextColor(R.id.legend_text_warning, secTextColor)
                views.setTextColor(R.id.legend_text_danger, secTextColor)

                // Apply dot colors
                views.setInt(R.id.legend_dot_good, "setColorFilter", safeColor)
                views.setInt(R.id.legend_dot_warning, "setColorFilter", warningColor)
                views.setInt(R.id.legend_dot_danger, "setColorFilter", dangerColor)
                
                // Clear existing views to prevent duplicates on refresh
                views.removeAllViews(R.id.widget_subject_list)

                if (jsonString != null) {
                    val jsonObj = JSONObject(jsonString)
                    val subjectsArray = jsonObj.optJSONArray("subjects") ?: JSONArray()
                    
                    for (i in 0 until subjectsArray.length()) {
                        val subjectObj = subjectsArray.getJSONObject(i)
                        val title = subjectObj.optString("title", "Unknown")
                        val percentage = subjectObj.optString("percentage", "N/A")
                        val level = subjectObj.optString("level", "unknown")
                        
                        val rowView = RemoteViews(context.packageName, R.layout.widget_subject_item)
                        rowView.setTextViewText(R.id.subject_text, "$title - $percentage")
                        rowView.setTextColor(R.id.subject_text, textColor)
                        
                        val dotColor = when (level) {
                            "good"    -> safeColor
                            "warning" -> warningColor
                            "danger"  -> dangerColor
                            else      -> secTextColor
                        }
                        rowView.setInt(R.id.subject_dot, "setColorFilter", dotColor)
                        
                        views.addView(R.id.widget_subject_list, rowView)
                        
                        // Add separator if not last item
                        if (i < subjectsArray.length() - 1) {
                            val separator = RemoteViews(context.packageName, R.layout.widget_separator)
                            separator.setInt(R.id.separator_line, "setBackgroundColor", dividerColor)
                            views.addView(R.id.widget_subject_list, separator)
                        }
                    }
                } else {
                    val rowView = RemoteViews(context.packageName, R.layout.widget_subject_item)
                    rowView.setTextViewText(R.id.subject_text, "Please open app to sync")
                    rowView.setTextColor(R.id.subject_text, secTextColor)
                    rowView.setInt(R.id.subject_dot, "setColorFilter", secTextColor)
                    views.addView(R.id.widget_subject_list, rowView)
                }

            } catch (e: Exception) {
                // Fallback in case of parsing error
            }

            // Tap → open app
            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(
                context, widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
