package com.studyapp.presentation.navigation

import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.EventNote
import androidx.compose.material.icons.filled.*

sealed class Screen(
    val route: String,
    val title: String,
    val icon: ImageVector
) {
    object Home : Screen("home", "ホーム", Icons.Default.Home)
    object Timer : Screen("timer", "タイマー", Icons.Default.Timer)
    object Materials : Screen("materials", "教材", Icons.Default.Book)
    object MaterialHistory : Screen("materials/{materialId}/history", "教材の履歴", Icons.Default.History) {
        fun createRoute(materialId: Long): String = "materials/$materialId/history"
    }
    object Calendar : Screen("calendar", "カレンダー", Icons.Default.CalendarMonth)
    object More : Screen("more", "More", Icons.Default.MoreHoriz)
    object Timetable : Screen("timetable", "時間割", Icons.Default.GridView)
    object Reports : Screen("reports", "レポート", Icons.Default.BarChart)
    object ScreenTime : Screen("screen_time", "Screen Time", Icons.Default.HourglassEmpty)
    object Exams : Screen("exams", "テスト", Icons.Default.Event)
    object Subjects : Screen("subjects", "科目", Icons.Default.Category)
    object History : Screen("history", "履歴", Icons.Default.History)
    object Goals : Screen("goals", "目標", Icons.Default.Flag)
    object Settings : Screen("settings", "設定", Icons.Default.Settings)
    object Plan : Screen("plan", "学習計画", Icons.AutoMirrored.Filled.EventNote)
}

val bottomScreens = listOf(
    Screen.Home,
    Screen.Timer,
    Screen.Materials,
    Screen.Calendar,
    Screen.More
)

val moreScreens = listOf(
    Screen.Timetable,
    Screen.Reports,
    Screen.ScreenTime,
    Screen.Settings
)
