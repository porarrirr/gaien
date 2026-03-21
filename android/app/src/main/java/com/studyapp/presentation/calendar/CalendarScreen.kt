package com.studyapp.presentation.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlin.math.ceil
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(
    viewModel: CalendarViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "カレンダー",
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
            CalendarHeader(
                year = uiState.currentYear,
                month = uiState.currentMonth,
                onPrevious = { viewModel.previousMonth() },
                onNext = { viewModel.nextMonth() }
            )
            
            CalendarGrid(
                year = uiState.currentYear,
                month = uiState.currentMonth,
                studyData = uiState.studyDataByDate,
                selectedDate = uiState.selectedDate,
                onDateSelect = { viewModel.selectDate(it) }
            )
            
            if (uiState.selectedDate != null) {
                SelectedDateSection(
                    date = uiState.selectedDate!!,
                    totalMinutes = uiState.selectedDateMinutes
                )
            }
        }
    }
}

@Composable
private fun CalendarHeader(
    year: Int,
    month: Int,
    onPrevious: () -> Unit,
    onNext: () -> Unit
) {
    val monthNames = listOf(
        "1月", "2月", "3月", "4月", "5月", "6月",
        "7月", "8月", "9月", "10月", "11月", "12月"
    )
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        FilledTonalIconButton(onClick = onPrevious) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "前月")
        }
        
        Text(
            text = "${year}年 ${monthNames[month - 1]}",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        
        FilledTonalIconButton(onClick = onNext) {
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "翌月")
        }
    }
}

@Composable
private fun CalendarGrid(
    year: Int,
    month: Int,
    studyData: Map<Int, Long>,
    selectedDate: Date?,
    onDateSelect: (Date) -> Unit
) {
    val calendar = Calendar.getInstance()
    calendar.set(year, month - 1, 1)
    
    val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
    val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
    val totalCells = firstDayOfWeek + daysInMonth
    val weekRows = ceil(totalCells / 7f).toInt()
    
    val weekDays = listOf("日", "月", "火", "水", "木", "金", "土")
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("calendar_grid")
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            weekDays.forEach { day ->
                Text(
                    text = day,
                    modifier = Modifier
                        .weight(1f)
                        .padding(8.dp),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp)
        ) {
            for (row in 0 until weekRows) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    for (col in 0 until 7) {
                        val cellIndex = row * 7 + col
                        val dayNumber = cellIndex - firstDayOfWeek + 1
                        
                        if (cellIndex < firstDayOfWeek || dayNumber > daysInMonth) {
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .aspectRatio(1f)
                            )
                        } else {
                            val studyMinutes = studyData[dayNumber] ?: 0L
                            val isSelected = selectedDate?.let {
                                val cal = Calendar.getInstance()
                                cal.time = it
                                cal.get(Calendar.YEAR) == year &&
                                    cal.get(Calendar.MONTH) == month - 1 &&
                                    cal.get(Calendar.DAY_OF_MONTH) == dayNumber
                            } ?: false
                            
                            val isToday = run {
                                val today = Calendar.getInstance()
                                today.get(Calendar.YEAR) == year &&
                                    today.get(Calendar.MONTH) == month - 1 &&
                                    today.get(Calendar.DAY_OF_MONTH) == dayNumber
                            }
                            
                            Box(modifier = Modifier.weight(1f)) {
                                DayCell(
                                    day = dayNumber,
                                    studyMinutes = studyMinutes,
                                    isSelected = isSelected,
                                    isToday = isToday,
                                    onClick = {
                                        val cal = Calendar.getInstance()
                                        cal.set(year, month - 1, dayNumber)
                                        onDateSelect(cal.time)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(
    day: Int,
    studyMinutes: Long,
    isSelected: Boolean,
    isToday: Boolean,
    onClick: () -> Unit
) {
    val primaryColor = MaterialTheme.colorScheme.primary
    val heatmapColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        studyMinutes > 120 -> MaterialTheme.colorScheme.primaryContainer
        studyMinutes in 61..120 -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.75f)
        studyMinutes in 31..60 -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
        studyMinutes in 1..30 -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
        else -> MaterialTheme.colorScheme.surface
    }
    
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .padding(2.dp)
            .testTag("calendar_day_$day")
            .then(
                if (isToday) Modifier.border(2.dp, primaryColor, CircleShape)
                else Modifier
            )
            .clip(CircleShape)
            .background(heatmapColor)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = day.toString(),
            color = when {
                isSelected -> MaterialTheme.colorScheme.onPrimary
                else -> MaterialTheme.colorScheme.onSurface
            },
            fontSize = 14.sp,
            fontWeight = if (isToday || isSelected) FontWeight.Bold else FontWeight.Normal
        )
    }
}

@Composable
private fun SelectedDateSection(
    date: Date,
    totalMinutes: Long
) {
    val dateFormat = SimpleDateFormat("M月d日 (E)", Locale.JAPANESE)
    
    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text(
                text = dateFormat.format(date),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            Row(
                verticalAlignment = Alignment.Bottom
            ) {
                Text(
                    text = totalMinutes.toString(),
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = "分",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
            }
        }
    }
}
