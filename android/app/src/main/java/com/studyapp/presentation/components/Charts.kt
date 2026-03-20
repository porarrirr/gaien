package com.studyapp.presentation.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.absoluteValue
import kotlin.math.max
import kotlin.math.min

data class BarChartData(
    val label: String,
    val value: Float,
    val color: Color = Color(0xFF4CAF50)
)

data class LineChartData(
    val x: Float,
    val y: Float,
    val label: String = ""
)

data class PieChartData(
    val label: String,
    val value: Float,
    val color: Color
)

data class HeatmapCell(
    val date: String,
    val value: Int,
    val dayOfWeek: Int
)

@Composable
fun BarChart(
    data: List<BarChartData>,
    modifier: Modifier = Modifier,
    title: String = "",
    showValues: Boolean = true,
    animated: Boolean = true,
    onBarClick: ((BarChartData) -> Unit)? = null
) {
    if (data.isEmpty()) {
        EmptyChartPlaceholder(
            title = title,
            message = "データがありません",
            modifier = modifier
        )
        return
    }
    
    val maxValue = remember(data) { data.maxOfOrNull { it.value } ?: 0f }
    var animationProgress by remember { mutableFloatStateOf(0f) }
    
    LaunchedEffect(data) {
        if (animated) {
            animate(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = Spring.StiffnessLow
                )
            ) { value, _ ->
                animationProgress = value
            }
        } else {
            animationProgress = 1f
        }
    }
    
    val contentDesc = if (title.isNotEmpty()) "$title: 棒グラフ" else "棒グラフ"
    
    Column(modifier = modifier.semantics { contentDescription = contentDesc }) {
        if (title.isNotEmpty()) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
        
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            data.forEach { barData ->
                val animatedHeight = if (maxValue > 0.001f) {
                    (barData.value / maxValue) * animationProgress
                } else 0f
                
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .pointerInput(barData) {
                            detectTapGestures {
                                onBarClick?.invoke(barData)
                            }
                        },
                    contentAlignment = Alignment.BottomCenter
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxHeight()
                    ) {
                        if (showValues && animatedHeight > 0.1f) {
                            Text(
                                text = barData.value.toInt().toString(),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(bottom = 4.dp)
                            )
                        }
                        
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(0.7f)
                                .fillMaxHeight(animatedHeight.coerceIn(0f, 1f))
                                .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                                .background(
                                    brush = Brush.verticalGradient(
                                        colors = listOf(
                                            barData.color,
                                            barData.color.copy(alpha = 0.7f)
                                        )
                                    )
                                )
                        )
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            data.forEach { barData ->
                Text(
                    text = barData.label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
fun LineChart(
    data: List<LineChartData>,
    modifier: Modifier = Modifier,
    title: String = "",
    lineColor: Color = Color(0xFF4CAF50),
    fillColor: Color = lineColor.copy(alpha = 0.2f),
    animated: Boolean = true,
    showDots: Boolean = true,
    curvedLines: Boolean = true
) {
    if (data.isEmpty()) {
        EmptyChartPlaceholder(
            title = title,
            message = "データがありません",
            modifier = modifier
        )
        return
    }
    
    val minX = remember(data) { data.minOfOrNull { it.x } ?: 0f }
    val maxX = remember(data) { data.maxOfOrNull { it.x } ?: 0f }
    val minY = remember(data) { data.minOfOrNull { it.y } ?: 0f }
    val maxY = remember(data) { data.maxOfOrNull { it.y } ?: 0f }
    
    val yRange = (maxY - minY).absoluteValue
    val xRange = (maxX - minX).absoluteValue
    
    var animationProgress by remember { mutableFloatStateOf(0f) }
    
    LaunchedEffect(data) {
        if (animated) {
            animate(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = tween(1000, easing = EaseOutCubic)
            ) { value, _ ->
                animationProgress = value
            }
        } else {
            animationProgress = 1f
        }
    }
    
    val contentDesc = if (title.isNotEmpty()) "$title: 折れ線グラフ" else "折れ線グラフ"
    
    Column(modifier = modifier.semantics { contentDescription = contentDesc }) {
        if (title.isNotEmpty()) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
        
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
        ) {
            val chartWidth = size.width - 40.dp.toPx()
            val chartHeight = size.height - 40.dp.toPx()
            val startX = 20.dp.toPx()
            val startY = 20.dp.toPx()
            
            drawLine(
                color = Color.Gray.copy(alpha = 0.3f),
                start = Offset(startX, startY + chartHeight),
                end = Offset(startX + chartWidth, startY + chartHeight),
                strokeWidth = 1.dp.toPx()
            )
            
            for (i in 0..4) {
                val y = startY + (chartHeight * i / 4)
                drawLine(
                    color = Color.Gray.copy(alpha = 0.1f),
                    start = Offset(startX, y),
                    end = Offset(startX + chartWidth, y),
                    strokeWidth = 1.dp.toPx()
                )
            }
            
            val points = data.map { point ->
                val normalizedX = if (xRange > 0.001f) (point.x - minX) / xRange else 0.5f
                val normalizedY = if (yRange > 0.001f) (point.y - minY) / yRange else 0.5f
                
                Offset(
                    startX + normalizedX * chartWidth,
                    startY + chartHeight - (normalizedY * chartHeight * animationProgress)
                )
            }
            
            if (points.size > 1) {
                val fillPath = Path().apply {
                    moveTo(points.first().x, startY + chartHeight)
                    if (curvedLines && points.size > 2) {
                        for (i in 0 until points.size - 1) {
                            val current = points[i]
                            val next = points[i + 1]
                            val midX = (current.x + next.x) / 2
                            quadraticBezierTo(current.x, current.y, midX, (current.y + next.y) / 2)
                        }
                        quadraticBezierTo(
                            points.last().x - (points.last().x - points[points.size - 2].x) / 2,
                            points.last().y,
                            points.last().x,
                            points.last().y
                        )
                    } else {
                        points.forEach { point ->
                            lineTo(point.x, point.y)
                        }
                    }
                    lineTo(points.last().x, startY + chartHeight)
                    close()
                }
                drawPath(fillPath, fillColor)
                
                val linePath = Path().apply {
                    moveTo(points.first().x, points.first().y)
                    if (curvedLines && points.size > 2) {
                        for (i in 0 until points.size - 1) {
                            val current = points[i]
                            val next = points[i + 1]
                            val midX = (current.x + next.x) / 2
                            quadraticBezierTo(current.x, current.y, midX, (current.y + next.y) / 2)
                        }
                        quadraticBezierTo(
                            points.last().x - (points.last().x - points[points.size - 2].x) / 2,
                            points.last().y,
                            points.last().x,
                            points.last().y
                        )
                    } else {
                        points.forEach { point ->
                            lineTo(point.x, point.y)
                        }
                    }
                }
                drawPath(
                    path = linePath,
                    color = lineColor,
                    style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
                )
            }
            
            if (showDots) {
                points.forEach { point ->
                    drawCircle(
                        color = Color.White,
                        radius = 6.dp.toPx(),
                        center = point
                    )
                    drawCircle(
                        color = lineColor,
                        radius = 4.dp.toPx(),
                        center = point
                    )
                }
            }
        }
    }
}

@Composable
fun PieChart(
    data: List<PieChartData>,
    modifier: Modifier = Modifier,
    title: String = "",
    animated: Boolean = true,
    showLabels: Boolean = true,
    centerText: String? = null
) {
    if (data.isEmpty()) {
        EmptyChartPlaceholder(
            title = title,
            message = "データがありません",
            modifier = modifier
        )
        return
    }
    
    val total = remember(data) { data.sumOf { it.value.toDouble() }.toFloat() }
    var animationProgress by remember { mutableFloatStateOf(0f) }
    
    LaunchedEffect(data) {
        if (animated) {
            animate(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = tween(800, easing = EaseOutCubic)
            ) { value, _ ->
                animationProgress = value
            }
        } else {
            animationProgress = 1f
        }
    }
    
    val contentDesc = if (title.isNotEmpty()) "$title: 円グラフ" else "円グラフ"
    
    Column(modifier = modifier.semantics { contentDescription = contentDesc }) {
        if (title.isNotEmpty()) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier.size(180.dp),
                contentAlignment = Alignment.Center
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    var startAngle = -90f
                    val sweepAngles = data.map { item ->
                        val sweep = if (total > 0.001f) (item.value / total) * 360f * animationProgress else 0f
                        sweep
                    }
                    
                    data.forEachIndexed { index, item ->
                        val sweep = sweepAngles[index]
                        drawArc(
                            color = item.color,
                            startAngle = startAngle,
                            sweepAngle = sweep,
                            useCenter = true,
                            style = Fill
                        )
                        
                        if (index < data.size - 1) {
                            drawArc(
                                color = Color.White,
                                startAngle = startAngle + sweep - 0.5f,
                                sweepAngle = 1f,
                                useCenter = true,
                                style = Fill
                            )
                        }
                        
                        startAngle += sweep
                    }
                }
                
                Canvas(modifier = Modifier.size(100.dp)) {
                    drawCircle(color = Color.White, radius = size.width / 2)
                }
                
                if (centerText != null) {
                    Text(
                        text = centerText,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                }
            }
            
            if (showLabels) {
                Spacer(modifier = Modifier.width(16.dp))
                
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    data.forEach { item ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(12.dp)
                                    .clip(CircleShape)
                                    .background(item.color)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = item.label,
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.width(60.dp)
                            )
                            Text(
                                text = if (total > 0.001f) "${((item.value / total) * 100).toInt()}%" else "0%",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun StudyHeatmap(
    data: List<HeatmapCell>,
    modifier: Modifier = Modifier,
    title: String = "学習ヒートマップ",
    weeksToShow: Int = 16,
    animated: Boolean = true
) {
    if (data.isEmpty()) {
        EmptyChartPlaceholder(
            title = title,
            message = "データがありません",
            modifier = modifier
        )
        return
    }
    
    var animationProgress by remember { mutableFloatStateOf(0f) }
    
    LaunchedEffect(data) {
        if (animated) {
            animate(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = tween(600, easing = EaseOutCubic)
            ) { value, _ ->
                animationProgress = value
            }
        } else {
            animationProgress = 1f
        }
    }
    
    Column(modifier = modifier.semantics { contentDescription = "$title: ヒートマップ" }) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        val weekDays = listOf("月", "", "水", "", "金", "", "日")
        
        Row(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(end = 4.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                weekDays.forEach { day ->
                    Text(
                        text = day,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.height(12.dp)
                    )
                }
            }
            
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                modifier = Modifier.weight(1f)
            ) {
                val groupedByWeek = data.groupBy { 
                    it.date.substringBefore("-") 
                }
                
                items(groupedByWeek.entries.toList()) { (_, cells) ->
                    Column(
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        for (dayOfWeek in 0..6) {
                            val cell = cells.find { it.dayOfWeek == dayOfWeek }
                            val intensity = cell?.value ?: 0
                            
                            val cellColor = when {
                                intensity == 0 -> MaterialTheme.colorScheme.surfaceVariant
                                intensity < 30 -> Color(0xFFC8E6C9)
                                intensity < 60 -> Color(0xFF81C784)
                                intensity < 120 -> Color(0xFF4CAF50)
                                intensity < 180 -> Color(0xFF388E3C)
                                else -> Color(0xFF1B5E20)
                            }
                            
                            Box(
                                modifier = Modifier
                                    .size(12.dp)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(cellColor.copy(alpha = animationProgress))
                            )
                        }
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "少",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(4.dp))
            listOf(
                MaterialTheme.colorScheme.surfaceVariant,
                Color(0xFFC8E6C9),
                Color(0xFF81C784),
                Color(0xFF4CAF50),
                Color(0xFF388E3C),
                Color(0xFF1B5E20)
            ).forEach { color ->
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(color)
                )
                Spacer(modifier = Modifier.width(2.dp))
            }
            Text(
                text = "多",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun StackedBarChart(
    data: List<List<BarChartData>>,
    labels: List<String>,
    modifier: Modifier = Modifier,
    title: String = "",
    animated: Boolean = true
) {
    if (data.isEmpty() || data.all { it.isEmpty() }) {
        EmptyChartPlaceholder(
            title = title,
            message = "データがありません",
            modifier = modifier
        )
        return
    }
    
    val maxTotal = remember(data) {
        data.maxOfOrNull { segments -> segments.sumOf { it.value.toDouble() }.toFloat() } ?: 0f
    }
    var animationProgress by remember { mutableFloatStateOf(0f) }
    
    LaunchedEffect(data) {
        if (animated) {
            animate(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = Spring.StiffnessLow
                )
            ) { value, _ ->
                animationProgress = value
            }
        } else {
            animationProgress = 1f
        }
    }
    
    val contentDesc = if (title.isNotEmpty()) "$title: 積み上げ棒グラフ" else "積み上げ棒グラフ"
    
    Column(modifier = modifier.semantics { contentDescription = contentDesc }) {
        if (title.isNotEmpty()) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
        
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            data.forEachIndexed { index, segments ->
                val segmentsTotal = segments.sumOf { it.value.toDouble() }.toFloat()
                val animatedHeight = if (maxTotal > 0.001f) {
                    (segmentsTotal / maxTotal) * animationProgress
                } else 0f
                
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    contentAlignment = Alignment.BottomCenter
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth(0.6f)
                            .fillMaxHeight(animatedHeight.coerceIn(0f, 1f))
                            .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                    ) {
                        segments.forEach { segment ->
                            val segmentHeight = if (segmentsTotal > 0.001f) {
                                (segment.value / segmentsTotal)
                            } else 0f
                            
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(segmentHeight.coerceIn(0.001f, 1f))
                                    .background(segment.color)
                            )
                        }
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            labels.forEach { label ->
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
fun HorizontalBarChart(
    data: List<BarChartData>,
    modifier: Modifier = Modifier,
    title: String = "",
    animated: Boolean = true,
    showValues: Boolean = true
) {
    if (data.isEmpty()) {
        EmptyChartPlaceholder(
            title = title,
            message = "データがありません",
            modifier = modifier
        )
        return
    }
    
    val maxValue = remember(data) { data.maxOfOrNull { it.value } ?: 0f }
    var animationProgress by remember { mutableFloatStateOf(0f) }
    
    LaunchedEffect(data) {
        if (animated) {
            animate(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = tween(800, easing = EaseOutCubic)
            ) { value, _ ->
                animationProgress = value
            }
        } else {
            animationProgress = 1f
        }
    }
    
    val contentDesc = if (title.isNotEmpty()) "$title: 横棒グラフ" else "横棒グラフ"
    
    Column(modifier = modifier.semantics { contentDescription = contentDesc }) {
        if (title.isNotEmpty()) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
        
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            data.forEach { barData ->
                val animatedWidth = if (maxValue > 0.001f) {
                    (barData.value / maxValue) * animationProgress
                } else 0f
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = barData.label,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.width(60.dp),
                        maxLines = 1
                    )
                    
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(24.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(animatedWidth.coerceIn(0f, 1f))
                                .fillMaxHeight()
                                .clip(RoundedCornerShape(4.dp))
                                .background(
                                    brush = Brush.horizontalGradient(
                                        colors = listOf(
                                            barData.color,
                                            barData.color.copy(alpha = 0.7f)
                                        )
                                    )
                                )
                        )
                    }
                    
                    if (showValues) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = barData.value.toInt().toString(),
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.width(40.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyChartPlaceholder(
    title: String,
    message: String,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        if (title.isNotEmpty()) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
        
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}