package com.studyapp.presentation.reports

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.presentation.components.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportsScreen(
    viewModel: ReportsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var selectedTab by remember { mutableStateOf(0) }
    val tabs = listOf("概要", "日別", "週別", "月別", "科目別")
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "レポート",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            ScrollableTabRow(
                selectedTabIndex = selectedTab,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.primary,
                edgePadding = 16.dp,
                divider = {}
            ) {
                tabs.forEachIndexed { index, title ->
                    Tab(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        text = { 
                            Text(
                                text = title,
                                fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Normal
                            )
                        }
                    )
                }
            }
            
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                when (selectedTab) {
                    0 -> {
                        item { OverviewSection(uiState) }
                    }
                    1 -> {
                        item { DailyReportSection(uiState) }
                    }
                    2 -> {
                        item { WeeklyReportSection(uiState) }
                    }
                    3 -> {
                        item { MonthlyReportSection(uiState) }
                    }
                    4 -> {
                        item { SubjectReportSection(uiState) }
                    }
                }
            }
        }
    }
}

@Composable
private fun OverviewSection(uiState: ReportsUiState) {
    SummaryStatsCard(
        totalTime = uiState.totalTime,
        averageTime = uiState.averageTime,
        streak = uiState.streakDays
    )
    
    Spacer(modifier = Modifier.height(16.dp))
    
    if (uiState.dailyData.isNotEmpty()) {
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "過去7日間の学習",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(16.dp))
                
                BarChart(
                    data = uiState.dailyData.map { data ->
                        BarChartData(
                            label = data.dateLabel.substringBefore(" "),
                            value = data.minutes.toFloat(),
                            color = if (data.minutes >= 120) MaterialTheme.colorScheme.primary
                                   else if (data.minutes >= 60) MaterialTheme.colorScheme.secondary
                                   else MaterialTheme.colorScheme.tertiary
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    showValues = true
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    if (uiState.subjectBreakdown.isNotEmpty()) {
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                PieChart(
                    data = uiState.subjectBreakdown.map { data ->
                        PieChartData(
                            label = data.subjectName,
                            value = (data.hours * 60 + data.minutes).toFloat(),
                            color = Color(data.color)
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    title = "科目別学習時間",
                    centerText = "${uiState.subjectBreakdown.sumOf { it.hours * 60 + it.minutes }}分"
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    QuickStatsRow(uiState)
}

@Composable
private fun SummaryStatsCard(
    totalTime: Long,
    averageTime: Long,
    streak: Int
) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            Text(
                text = "学習サマリー",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
            
            Spacer(modifier = Modifier.height(20.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                StatItem(
                    icon = Icons.Default.AccessTime,
                    label = "合計時間",
                    value = "${totalTime / 60}時間",
                    subValue = "${totalTime % 60}分",
                    color = MaterialTheme.colorScheme.primary
                )
                
                StatItem(
                    icon = Icons.Default.TrendingUp,
                    label = "1日平均",
                    value = "${averageTime}分",
                    color = MaterialTheme.colorScheme.secondary
                )
                
                StatItem(
                    icon = Icons.Default.LocalFireDepartment,
                    label = "連続学習",
                    value = "${streak}日",
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
        }
    }
}

@Composable
private fun StatItem(
    icon: ImageVector,
    label: String,
    value: String,
    subValue: String? = null,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(color.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(24.dp)
            )
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Row(
            verticalAlignment = Alignment.Bottom
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = color
            )
            if (subValue != null) {
                Spacer(modifier = Modifier.width(2.dp))
                Text(
                    text = subValue,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }
        }
    }
}

@Composable
private fun QuickStatsRow(uiState: ReportsUiState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        QuickStatCard(
            title = "今日",
            value = uiState.dailyData.lastOrNull()?.minutes?.toString() ?: "0",
            unit = "分",
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.primary
        )
        
        QuickStatCard(
            title = "今週",
            value = uiState.weeklyData.lastOrNull()?.let { "${it.hours}h${it.minutes}m" } ?: "0分",
            unit = "",
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.secondary
        )
        
        QuickStatCard(
            title = "今月",
            value = "${uiState.monthlyData.lastOrNull()?.totalHours ?: 0}",
            unit = "時間",
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.tertiary
        )
    }
}

@Composable
private fun QuickStatCard(
    title: String,
    value: String,
    unit: String,
    modifier: Modifier = Modifier,
    color: Color
) {
    ElevatedCard(
        modifier = modifier,
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(4.dp))
            Row(
                verticalAlignment = Alignment.Bottom
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = color
                )
                if (unit.isNotEmpty()) {
                    Spacer(modifier = Modifier.width(2.dp))
                    Text(
                        text = unit,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(bottom = 2.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun DailyReportSection(uiState: ReportsUiState) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "日別学習時間",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (uiState.dailyData.isNotEmpty()) {
                BarChart(
                    data = uiState.dailyData.map { data ->
                        BarChartData(
                            label = data.dateLabel.substringBefore(" ("),
                            value = data.minutes.toFloat(),
                            color = when {
                                data.minutes >= 180 -> Color(0xFF1B5E20)
                                data.minutes >= 120 -> Color(0xFF388E3C)
                                data.minutes >= 60 -> MaterialTheme.colorScheme.primary
                                data.minutes >= 30 -> Color(0xFF81C784)
                                else -> Color(0xFFC8E6C9)
                            }
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    title = "過去7日間"
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "学習時間推移",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (uiState.dailyData.isNotEmpty()) {
                LineChart(
                    data = uiState.dailyData.mapIndexed { index, data ->
                        LineChartData(
                            x = index.toFloat(),
                            y = data.minutes.toFloat(),
                            label = data.dateLabel
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    lineColor = MaterialTheme.colorScheme.primary,
                    showDots = true,
                    curvedLines = true
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "詳細データ",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            uiState.dailyData.forEach { data ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = data.dateLabel,
                        style = MaterialTheme.typography.bodyMedium
                    )
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .width(100.dp)
                                .height(8.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(MaterialTheme.colorScheme.surfaceVariant)
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth((data.minutes.coerceAtMost(240) / 240f).coerceIn(0f, 1f))
                                    .fillMaxHeight()
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(
                                        when {
                                            data.minutes >= 120 -> MaterialTheme.colorScheme.primary
                                            data.minutes >= 60 -> MaterialTheme.colorScheme.secondary
                                            else -> MaterialTheme.colorScheme.tertiary
                                        }
                                    )
                            )
                        }
                        
                        Spacer(modifier = Modifier.width(12.dp))
                        
                        Text(
                            text = "${data.minutes}分",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun WeeklyReportSection(uiState: ReportsUiState) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "週間学習時間",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (uiState.weeklyData.isNotEmpty()) {
                BarChart(
                    data = uiState.weeklyData.map { data ->
                        BarChartData(
                            label = data.weekLabel,
                            value = (data.hours * 60 + data.minutes).toFloat(),
                            color = MaterialTheme.colorScheme.secondary
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    title = "過去4週間"
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "週間推移",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (uiState.weeklyData.isNotEmpty()) {
                LineChart(
                    data = uiState.weeklyData.mapIndexed { index, data ->
                        LineChartData(
                            x = index.toFloat(),
                            y = (data.hours * 60 + data.minutes).toFloat(),
                            label = data.weekLabel
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    lineColor = MaterialTheme.colorScheme.secondary
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "週間サマリー",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            uiState.weeklyData.forEach { data ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = data.weekLabel,
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = "${data.hours}時間${data.minutes}分",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.secondary
                    )
                }
            }
        }
    }
}

@Composable
private fun MonthlyReportSection(uiState: ReportsUiState) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "月間学習時間",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (uiState.monthlyData.isNotEmpty()) {
                BarChart(
                    data = uiState.monthlyData.map { data ->
                        BarChartData(
                            label = data.monthLabel,
                            value = data.totalHours.toFloat(),
                            color = MaterialTheme.colorScheme.tertiary
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    title = "過去6ヶ月"
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "月間推移",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (uiState.monthlyData.isNotEmpty()) {
                LineChart(
                    data = uiState.monthlyData.mapIndexed { index, data ->
                        LineChartData(
                            x = index.toFloat(),
                            y = data.totalHours.toFloat(),
                            label = data.monthLabel
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    lineColor = MaterialTheme.colorScheme.tertiary
                )
            }
        }
    }
    
    Spacer(modifier = Modifier.height(16.dp))
    
    val totalHours = uiState.monthlyData.sumOf { it.totalHours.toLong() }
    val averageMonthly = if (uiState.monthlyData.isNotEmpty()) totalHours / uiState.monthlyData.size else 0
    
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        ElevatedCard(
            modifier = Modifier.weight(1f),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "総学習時間",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "${totalHours}時間",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
        }
        
        ElevatedCard(
            modifier = Modifier.weight(1f),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "月平均",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "${averageMonthly}時間",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.secondary
                )
            }
        }
    }
}

@Composable
private fun SubjectReportSection(uiState: ReportsUiState) {
    if (uiState.subjectBreakdown.isEmpty()) {
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    Icons.Default.PieChart,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "学習記録がありません",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    } else {
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                PieChart(
                    data = uiState.subjectBreakdown.map { data ->
                        PieChartData(
                            label = data.subjectName,
                            value = (data.hours * 60 + data.minutes).toFloat(),
                            color = Color(data.color)
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    title = "科目別学習比率"
                )
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "科目別学習時間",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                HorizontalBarChart(
                    data = uiState.subjectBreakdown.map { data ->
                        BarChartData(
                            label = data.subjectName,
                            value = (data.hours * 60 + data.minutes).toFloat(),
                            color = Color(data.color)
                        )
                    },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "科目ランキング",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                uiState.subjectBreakdown.take(5).forEachIndexed { index, data ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(
                                    when (index) {
                                        0 -> Color(0xFFFFD700)
                                        1 -> Color(0xFFC0C0C0)
                                        2 -> Color(0xFFCD7F32)
                                        else -> MaterialTheme.colorScheme.surfaceVariant
                                    }
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "${index + 1}",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                color = if (index < 3) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        
                        Spacer(modifier = Modifier.width(12.dp))
                        
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .clip(CircleShape)
                                .background(Color(data.color))
                        )
                        
                        Spacer(modifier = Modifier.width(8.dp))
                        
                        Text(
                            text = data.subjectName,
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f)
                        )
                        
                        Text(
                            text = "${data.hours}時間${data.minutes}分",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}