package com.studyapp.presentation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.studyapp.presentation.home.HomeScreen
import com.studyapp.presentation.timer.TimerScreen
import com.studyapp.presentation.materials.MaterialsScreen
import com.studyapp.presentation.calendar.CalendarScreen
import com.studyapp.presentation.reports.ReportsScreen
import com.studyapp.presentation.exams.ExamsScreen
import com.studyapp.presentation.subjects.SubjectsScreen
import com.studyapp.presentation.history.HistoryScreen
import com.studyapp.presentation.settings.SettingsScreen
import com.studyapp.presentation.goals.GoalsScreen
import com.studyapp.presentation.plans.PlanScreen
import com.studyapp.presentation.navigation.Screen
import com.studyapp.presentation.navigation.bottomScreens

private const val NAV_ANIM_DURATION = 300

private fun defaultEnterTransition(): AnimatedContentTransitionScope<NavBackStackEntry>.() -> EnterTransition = {
    fadeIn(animationSpec = tween(NAV_ANIM_DURATION)) +
        slideIntoContainer(
            towards = AnimatedContentTransitionScope.SlideDirection.Up,
            animationSpec = tween(NAV_ANIM_DURATION),
            initialOffset = { it / 8 }
        )
}

private fun defaultExitTransition(): AnimatedContentTransitionScope<NavBackStackEntry>.() -> ExitTransition = {
    fadeOut(animationSpec = tween(NAV_ANIM_DURATION))
}

private fun defaultPopEnterTransition(): AnimatedContentTransitionScope<NavBackStackEntry>.() -> EnterTransition = {
    fadeIn(animationSpec = tween(NAV_ANIM_DURATION))
}

private fun defaultPopExitTransition(): AnimatedContentTransitionScope<NavBackStackEntry>.() -> ExitTransition = {
    fadeOut(animationSpec = tween(NAV_ANIM_DURATION)) +
        slideOutOfContainer(
            towards = AnimatedContentTransitionScope.SlideDirection.Down,
            animationSpec = tween(NAV_ANIM_DURATION),
            targetOffset = { it / 8 }
        )
}

@Composable
fun MainScreen() {
    val navController = rememberNavController()

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                tonalElevation = NavigationBarDefaults.Elevation
            ) {
                val navBackStackEntry by navController.currentBackStackEntryAsState()
                val currentDestination = navBackStackEntry?.destination

                bottomScreens.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.title) },
                        label = {
                            Text(
                                screen.title,
                                style = MaterialTheme.typography.labelSmall
                            )
                        },
                        selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.onPrimaryContainer,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            indicatorColor = MaterialTheme.colorScheme.primaryContainer,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    )
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(paddingValues),
            enterTransition = defaultEnterTransition(),
            exitTransition = defaultExitTransition(),
            popEnterTransition = defaultPopEnterTransition(),
            popExitTransition = defaultPopExitTransition()
        ) {
            composable(Screen.Home.route) {
                HomeScreen(
                    onNavigateToTimer = { navController.navigate(Screen.Timer.route) },
                    onNavigateToMaterials = { navController.navigate(Screen.Materials.route) },
                    onNavigateToExams = { navController.navigate(Screen.Exams.route) },
                    onNavigateToGoals = { navController.navigate(Screen.Goals.route) },
                    onNavigateToHistory = { navController.navigate(Screen.History.route) },
                    onNavigateToSettings = { navController.navigate(Screen.Settings.route) },
                    onNavigateToPlan = { navController.navigate(Screen.Plan.route) }
                )
            }
            composable(Screen.Timer.route) {
                TimerScreen()
            }
            composable(Screen.Materials.route) {
                MaterialsScreen(
                    onNavigateToSubjects = { navController.navigate(Screen.Subjects.route) }
                )
            }
            composable(Screen.Calendar.route) {
                CalendarScreen()
            }
            composable(Screen.Reports.route) {
                ReportsScreen()
            }
            composable(Screen.Exams.route) {
                ExamsScreen()
            }
            composable(Screen.Subjects.route) {
                SubjectsScreen()
            }
            composable(Screen.History.route) {
                HistoryScreen()
            }
            composable(Screen.Goals.route) {
                GoalsScreen()
            }
            composable(Screen.Settings.route) {
                SettingsScreen()
            }
            composable(Screen.Plan.route) {
                PlanScreen()
            }
        }
    }
}
