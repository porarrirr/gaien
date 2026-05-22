package com.studyapp.presentation.materials

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.studyapp.domain.model.MaterialListProgressSummary
import com.studyapp.presentation.components.AnimatedProgressBar
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

@Composable
fun MaterialProgressRing(
    progress: Float,
    accentColor: Color,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.size(78.dp), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val stroke = 7.dp.toPx()
            val diameter = min(size.width, size.height) - stroke
            val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
            drawArc(
                color = Color.LightGray.copy(alpha = 0.5f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = Size(diameter, diameter),
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
            drawArc(
                color = accentColor,
                startAngle = -90f,
                sweepAngle = 360f * progress.coerceIn(0f, 1f),
                useCenter = false,
                topLeft = topLeft,
                size = Size(diameter, diameter),
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "${(progress * 100).toInt()}%",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "正誤率",
                style = MaterialTheme.typography.labelSmall
            )
        }
    }
}

@Composable
fun MaterialCountTile(
    title: String,
    value: Int,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(7.dp))
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(title, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold)
        Text(
            text = "${value}問",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = color
        )
    }
}

@Composable
fun MaterialProblemLegend(
    summary: MaterialListProgressSummary,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.width(92.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
        LegendRow("正解", Color(0xFF4CAF50), summary.correctPercent)
        LegendRow("誤答", MaterialTheme.colorScheme.error, summary.wrongPercent)
        LegendRow("復習正解", Color(0xFFFF9800), summary.reviewCorrectPercent)
        LegendRow("未解答", Color.LightGray, summary.untouchedPercent)
    }
}

@Composable
private fun LegendRow(title: String, color: Color, percent: Int) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(color, RoundedCornerShape(2.dp))
        )
        Spacer(modifier = Modifier.width(5.dp))
        Text(title, style = MaterialTheme.typography.labelSmall, modifier = Modifier.weight(1f))
        Text("$percent%", style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
fun MaterialProblemPieChart(
    summary: MaterialListProgressSummary,
    modifier: Modifier = Modifier
) {
    val segments = listOf(
        summary.correctCount to Color(0xFF4CAF50),
        summary.wrongCount to MaterialTheme.colorScheme.error,
        summary.reviewCorrectCount to Color(0xFFFF9800),
        summary.untouchedCount to Color.LightGray
    ).filter { it.first > 0 }

    Canvas(modifier = modifier.size(58.dp)) {
        if (summary.totalProblems <= 0 || segments.isEmpty()) return@Canvas
        var start = -Math.PI / 2
        val total = summary.totalProblems.toDouble()
        segments.forEach { (value, color) ->
            val sweep = (value / total) * 2 * Math.PI
            val end = start + sweep
            val path = androidx.compose.ui.graphics.Path().apply {
                moveTo(center.x, center.y)
                val radius = min(size.width, size.height) / 2f
                var step = 0
                val steps = maxOf((sweep * 96).toInt(), 1)
                while (step <= steps) {
                    val fraction = step.toDouble() / steps.toDouble()
                    val angle = start + sweep * fraction
                    lineTo(
                        center.x + radius * sin(angle).toFloat(),
                        center.y - radius * cos(angle).toFloat()
                    )
                    step += 1
                }
                close()
            }
            drawPath(path, color)
            start = end
        }
    }
}

@Composable
fun MaterialProblemProgressSection(
    totalProblems: Int,
    chapterCount: Int,
    summary: MaterialListProgressSummary,
    accentColor: Color,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Bottom
                ) {
                    Text("正誤率", style = MaterialTheme.typography.labelSmall)
                    Text(
                        text = if (summary.totalProblems > 0) {
                            "${summary.correctCount + summary.reviewCorrectCount} / ${summary.totalProblems} 問"
                        } else {
                            "記録なし"
                        },
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AnimatedProgressBar(
                        progress = summary.answerAccuracyPercent / 100f,
                        modifier = Modifier.weight(1f),
                        height = 7.dp,
                        progressColor = accentColor
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "${summary.answerAccuracyPercent}%",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text("問題数", style = MaterialTheme.typography.labelSmall)
                    Text(
                        text = "${totalProblems}問",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 4.dp)
                    )
                    if (chapterCount > 0) {
                        Text(
                            text = "（全${chapterCount}章）",
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    Text("進捗", style = MaterialTheme.typography.labelSmall)
                    Text(
                        text = "${summary.progressedCount}問",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF4CAF50),
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }
            }
            MaterialProgressRing(
                progress = summary.answerAccuracyPercent / 100f,
                accentColor = accentColor
            )
        }

        HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(modifier = Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MaterialCountTile("正解", summary.correctCount, Color(0xFF4CAF50), Modifier.weight(1f))
                MaterialCountTile("誤答", summary.wrongCount, MaterialTheme.colorScheme.error, Modifier.weight(1f))
                MaterialCountTile("復習済", summary.reviewCorrectCount, Color(0xFFFF9800), Modifier.weight(1f))
            }
            MaterialProblemPieChart(summary)
            Spacer(modifier = Modifier.width(8.dp))
            MaterialProblemLegend(summary)
        }
    }
}

@Composable
fun SubjectColorDot(color: Int, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(14.dp)
            .background(Color(color), CircleShape)
    )
}
