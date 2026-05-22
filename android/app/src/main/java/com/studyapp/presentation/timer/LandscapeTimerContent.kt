package com.studyapp.presentation.timer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.studyapp.domain.model.LandscapeTimerDisplayPreset
import com.studyapp.domain.usecase.TimerMode
import com.studyapp.presentation.components.CircularProgressRing
import com.studyapp.presentation.components.PulsingEffect

@Composable
fun LandscapeTimerContent(
    preset: LandscapeTimerDisplayPreset,
    timeText: String,
    modeLabel: String,
    progress: Float,
    isRunning: Boolean,
    timerMode: TimerMode,
    problemStates: Map<Int, ProblemTileState>,
    problemCount: Int,
    onPauseToggle: () -> Unit,
    onStop: () -> Unit,
    onProblemToggle: (Int) -> Unit
) {
    val background = Brush.verticalGradient(
        colors = listOf(Color(0xFF090B10), Color.Black)
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(background)
            .padding(horizontal = 24.dp, vertical = 16.dp)
    ) {
        when (preset) {
            LandscapeTimerDisplayPreset.CLOCK_ONLY -> LandscapeClockOnlyContent(
                timeText = timeText,
                modeLabel = modeLabel,
                progress = progress,
                isRunning = isRunning,
                onPauseToggle = onPauseToggle,
                onStop = onStop
            )
            LandscapeTimerDisplayPreset.PROBLEM_PROGRESS -> LandscapeProblemProgressContent(
                timeText = timeText,
                modeLabel = modeLabel,
                progress = progress,
                isRunning = isRunning,
                problemStates = problemStates,
                problemCount = problemCount,
                onPauseToggle = onPauseToggle,
                onStop = onStop,
                onProblemToggle = onProblemToggle
            )
        }
    }
}

@Composable
private fun LandscapeClockOnlyContent(
    timeText: String,
    modeLabel: String,
    progress: Float,
    isRunning: Boolean,
    onPauseToggle: () -> Unit,
    onStop: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        PulsingEffect(isPulsing = isRunning) {
            CircularProgressRing(
                progress = progress.coerceIn(0f, 1f),
                size = 260.dp,
                strokeWidth = 12.dp,
                showPercentage = false,
                trackColor = Color.White.copy(alpha = 0.14f),
                progressColor = Color(0xFF69E07A),
                centerContent = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = timeText,
                            fontSize = 52.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = modeLabel,
                            color = Color.White.copy(alpha = 0.72f),
                            fontSize = 16.sp
                        )
                    }
                }
            )
        }
        Spacer(modifier = Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = onPauseToggle) {
                Icon(
                    if (isRunning) Icons.Default.Pause else Icons.Default.PlayArrow,
                    contentDescription = null
                )
            }
            Button(onClick = onStop) {
                Icon(Icons.Default.Stop, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("停止")
            }
        }
    }
}

@Composable
private fun LandscapeProblemProgressContent(
    timeText: String,
    modeLabel: String,
    progress: Float,
    isRunning: Boolean,
    problemStates: Map<Int, ProblemTileState>,
    problemCount: Int,
    onPauseToggle: () -> Unit,
    onStop: () -> Unit,
    onProblemToggle: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Column(
            modifier = Modifier
                .width(320.dp)
                .fillMaxHeight(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            PulsingEffect(isPulsing = isRunning) {
                CircularProgressRing(
                    progress = progress.coerceIn(0f, 1f),
                    size = 220.dp,
                    strokeWidth = 10.dp,
                    showPercentage = false,
                    trackColor = Color.White.copy(alpha = 0.14f),
                    progressColor = Color(0xFF69E07A),
                    centerContent = {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = timeText,
                                fontSize = 40.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                            Text(modeLabel, color = Color.White.copy(alpha = 0.72f))
                        }
                    }
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IconButton(onClick = onPauseToggle) {
                    Icon(
                        if (isRunning) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = null,
                        tint = Color.White
                    )
                }
                IconButton(onClick = onStop) {
                    Icon(Icons.Default.Stop, contentDescription = null, tint = Color(0xFFFF6B6B))
                }
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
        ) {
            Text(
                text = "問題進捗",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            if (problemCount <= 0) {
                Text(
                    text = "問題数を設定するとここにタイルが表示されます",
                    color = Color.White.copy(alpha = 0.7f)
                )
            } else {
                Column(
                    modifier = Modifier
                        .verticalScroll(rememberScrollState())
                        .fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    (1..problemCount).forEach { number ->
                        val state = problemStates[number] ?: ProblemTileState.UNTOUCHED
                        val tileColor = when (state) {
                            ProblemTileState.CORRECT -> Color(0xFF4CAF50)
                            ProblemTileState.WRONG -> Color(0xFFE53935)
                            ProblemTileState.UNTOUCHED -> Color.White.copy(alpha = 0.12f)
                        }
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(tileColor)
                                .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(8.dp))
                                .clickable { onProblemToggle(number) },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = number.toString(),
                                color = Color.White,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}
