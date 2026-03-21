package com.studyapp.presentation.calendar

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
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
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
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
        IconButton(onClick = onPrevious) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "前月")
        }
        
        Text(
            text = "${year}年 ${monthNames[month - 1]}",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        
        IconButton(onClick = onNext) {
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
    
    Column {
        Row(
            modifier = Modifier.fillMaxWidth()
        ) {
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
        
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp)
        ) {
            val cellSize = maxWidth / 7
            val gridHeight = cellSize * weekRows

            LazyVerticalGrid(
                columns = GridCells.Fixed(7),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(gridHeight)
                    .testTag("calendar_grid"),
                userScrollEnabled = false
            ) {
                items(firstDayOfWeek) {
                    Box(modifier = Modifier.aspectRatio(1f))
                }
                
                items(daysInMonth) { day ->
                    val studyMinutes = studyData[day + 1] ?: 0L
                    val isSelected = selectedDate?.let {
                        val cal = Calendar.getInstance()
                        cal.time = it
                        cal.get(Calendar.YEAR) == year &&
                            cal.get(Calendar.MONTH) == month - 1 &&
                            cal.get(Calendar.DAY_OF_MONTH) == day + 1
                    } ?: false
                    
                    val isToday = run {
                        val today = Calendar.getInstance()
                        today.get(Calendar.YEAR) == year &&
                            today.get(Calendar.MONTH) == month - 1 &&
                            today.get(Calendar.DAY_OF_MONTH) == day + 1
                    }
                    
                    DayCell(
                        day = day + 1,
                        studyMinutes = studyMinutes,
                        isSelected = isSelected,
                        isToday = isToday,
                        onClick = {
                            val cal = Calendar.getInstance()
                            cal.set(year, month - 1, day + 1)
                            onDateSelect(cal.time)
                        }
                    )
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
    val backgroundColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        studyMinutes > 180 -> MaterialTheme.colorScheme.primaryContainer
        studyMinutes > 60 -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
        studyMinutes > 0 -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
        else -> MaterialTheme.colorScheme.surface
    }
    
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .padding(2.dp)
            .testTag("calendar_day_$day")
            .clip(CircleShape)
            .background(backgroundColor)
            .clickable(onClick = onClick)
            .then(
                if (isToday && !isSelected) {
                    Modifier
                        .padding(1.dp)
                } else Modifier
            ),
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
    
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
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
