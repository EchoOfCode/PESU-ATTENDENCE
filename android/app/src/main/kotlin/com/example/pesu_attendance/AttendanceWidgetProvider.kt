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

                // Theme colors
                var bgRes = R.drawable.widget_background
                var textColor = 0xFFFFFFFF.toInt()
                var secTextColor = 0xFF9AA0A6.toInt()
                var safeColor = 0xFF81C995.toInt()
                var warningColor = 0xFFFDE293.toInt()
                var dangerColor = 0xFFF28B82.toInt()
                var dividerColor = 0x1AFFFFFF.toInt()
                var accentBg = 0x10FFFFFF.toInt()
                var quoteColor = 0xFF6B7280.toInt()

                when (appTheme) {
                    "funny" -> {
                        bgRes = R.drawable.widget_bg_funny
                        textColor = 0xFF000000.toInt()
                        secTextColor = 0xFF444444.toInt()
                        safeColor = 0xFF10B981.toInt()
                        warningColor = 0xFFF59E0B.toInt()
                        dangerColor = 0xFFDC2626.toInt()
                        dividerColor = 0x22000000.toInt()
                        accentBg = 0x10000000.toInt()
                        quoteColor = 0xFF666666.toInt()
                    }
                    "cute" -> {
                        bgRes = R.drawable.widget_bg_cute
                        textColor = 0xFF5D3A9B.toInt()
                        secTextColor = 0xFF9B7EBD.toInt()
                        safeColor = 0xFF5ED5A8.toInt()
                        warningColor = 0xFFFFB26B.toInt()
                        dangerColor = 0xFFFF9AA2.toInt()
                        dividerColor = 0x225D3A9B.toInt()
                        accentBg = 0x105D3A9B.toInt()
                        quoteColor = 0xFFB8A0D6.toInt()
                    }
                }

                // Apply background to container
                views.setInt(R.id.widget_container, "setBackgroundResource", bgRes)

                // Clear all dynamic content
                views.removeAllViews(R.id.widget_container)

                if (jsonString != null) {
                    val json = JSONObject(jsonString)

                    // --- Section 1: Header row (date + last updated) ---
                    val headerView = RemoteViews(context.packageName, R.layout.widget_header_row)
                    headerView.setTextViewText(R.id.header_date, json.optString("dateStr", ""))
                    headerView.setTextViewText(R.id.header_updated, json.optString("lastUpdated", ""))
                    headerView.setTextColor(R.id.header_date, textColor)
                    headerView.setTextColor(R.id.header_updated, secTextColor)
                    views.addView(R.id.widget_container, headerView)

                    // --- Section 2: Next class / break message ---
                    val nextName = json.optString("nextClassName", "")
                    val nextTime = json.optString("nextClassTime", "")
                    val breakMsg = json.optString("breakMessage", "")

                    val nextClassView = RemoteViews(context.packageName, R.layout.widget_next_class)
                    if (nextName.isNotEmpty()) {
                        nextClassView.setTextViewText(R.id.next_class_icon, "📖")
                        nextClassView.setTextViewText(R.id.next_class_label, "Next: $nextName")
                        nextClassView.setTextViewText(R.id.next_class_time, nextTime)
                        nextClassView.setTextColor(R.id.next_class_time, safeColor)
                    } else if (breakMsg.isNotEmpty()) {
                        nextClassView.setTextViewText(R.id.next_class_icon, "🎉")
                        nextClassView.setTextViewText(R.id.next_class_label, breakMsg)
                        nextClassView.setTextViewText(R.id.next_class_time, "")
                    } else {
                        nextClassView.setTextViewText(R.id.next_class_icon, "📋")
                        nextClassView.setTextViewText(R.id.next_class_label, "Add timetable in settings")
                        nextClassView.setTextViewText(R.id.next_class_time, "")
                    }
                    nextClassView.setTextColor(R.id.next_class_label, textColor)
                    views.addView(R.id.widget_container, nextClassView)

                    // --- Section 3: Subject list ---
                    val subjectsArray = json.optJSONArray("subjects") ?: JSONArray()
                    for (i in 0 until subjectsArray.length()) {
                        val subj = subjectsArray.getJSONObject(i)
                        val title = subj.optString("title", "Unknown")
                        val pct = subj.optString("percentage", "N/A")
                        val level = subj.optString("level", "unknown")

                        val rowView = RemoteViews(context.packageName, R.layout.widget_subject_item)
                        rowView.setTextViewText(R.id.subject_text, "$title - $pct")
                        rowView.setTextColor(R.id.subject_text, textColor)

                        val dotColor = when (level) {
                            "good"    -> safeColor
                            "warning" -> warningColor
                            "danger"  -> dangerColor
                            else      -> secTextColor
                        }
                        rowView.setInt(R.id.subject_dot, "setColorFilter", dotColor)
                        views.addView(R.id.widget_container, rowView)

                        // Separator between subjects
                        if (i < subjectsArray.length() - 1) {
                            val sep = RemoteViews(context.packageName, R.layout.widget_separator)
                            sep.setInt(R.id.separator_line, "setBackgroundColor", dividerColor)
                            views.addView(R.id.widget_container, sep)
                        }
                    }

                    // --- Section 4: Academic dates ---
                    val acLabel = json.optString("academicDateLabel", "")
                    val acValue = json.optString("academicDateValue", "")
                    if (acLabel.isNotEmpty()) {
                        val acView = RemoteViews(context.packageName, R.layout.widget_academic_dates)
                        acView.setTextViewText(R.id.academic_dates_text, "🗓 $acLabel: $acValue")
                        acView.setTextColor(R.id.academic_dates_text, secTextColor)
                        views.addView(R.id.widget_container, acView)
                    }

                    // --- Section 5: Funny quote footer ---
                    val quote = json.optString("funnyQuote", "")
                    if (quote.isNotEmpty()) {
                        val quoteView = RemoteViews(context.packageName, R.layout.widget_footer_quote)
                        quoteView.setTextViewText(R.id.footer_quote, quote)
                        quoteView.setTextColor(R.id.footer_quote, quoteColor)
                        views.addView(R.id.widget_container, quoteView)
                    }

                } else {
                    // No data yet — show placeholder
                    val rowView = RemoteViews(context.packageName, R.layout.widget_subject_item)
                    rowView.setTextViewText(R.id.subject_text, "Please open app to sync")
                    rowView.setTextColor(R.id.subject_text, secTextColor)
                    rowView.setInt(R.id.subject_dot, "setColorFilter", secTextColor)
                    views.addView(R.id.widget_container, rowView)
                }

            } catch (e: Exception) {
                // Fallback — silently fail to avoid widget crashes
            }

            // Tap anywhere → open app
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
