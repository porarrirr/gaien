package com.studyapp.presentation.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer

object AnimationUtils {
    
    fun enterAnimation(
        initialOffsetY: Int = 40,
        durationMillis: Int = 300
    ): EnterTransition {
        return slideInVertically(
            animationSpec = tween(durationMillis),
            initialOffsetY = { initialOffsetY }
        ) + fadeIn(
            animationSpec = tween(durationMillis)
        )
    }
    
    fun exitAnimation(
        targetOffsetY: Int = -40,
        durationMillis: Int = 300
    ): ExitTransition {
        return slideOutVertically(
            animationSpec = tween(durationMillis),
            targetOffsetY = { targetOffsetY }
        ) + fadeOut(
            animationSpec = tween(durationMillis)
        )
    }
    
    fun scaleEnterAnimation(
        initialScale: Float = 0.8f,
        durationMillis: Int = 300
    ): EnterTransition {
        return scaleIn(
            animationSpec = tween(durationMillis),
            initialScale = initialScale
        ) + fadeIn(
            animationSpec = tween(durationMillis)
        )
    }
    
    fun scaleExitAnimation(
        targetScale: Float = 0.8f,
        durationMillis: Int = 300
    ): ExitTransition {
        return scaleOut(
            animationSpec = tween(durationMillis),
            targetScale = targetScale
        ) + fadeOut(
            animationSpec = tween(durationMillis)
        )
    }
    
    fun slideInFromRight(durationMillis: Int = 300): EnterTransition {
        return slideInHorizontally(
            animationSpec = tween(durationMillis),
            initialOffsetX = { it }
        ) + fadeIn(
            animationSpec = tween(durationMillis)
        )
    }
    
    fun slideOutToLeft(durationMillis: Int = 300): ExitTransition {
        return slideOutHorizontally(
            animationSpec = tween(durationMillis),
            targetOffsetX = { -it }
        ) + fadeOut(
            animationSpec = tween(durationMillis)
        )
    }
    
    fun expandVerticallyAnimation(): EnterTransition {
        return expandVertically(
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessLow
            )
        ) + fadeIn(
            animationSpec = tween(300)
        )
    }
    
    fun shrinkVerticallyAnimation(): ExitTransition {
        return shrinkVertically(
            animationSpec = tween(300)
        ) + fadeOut(
            animationSpec = tween(300)
        )
    }
}

@Composable
fun ShimmerEffect(
    isLoading: Boolean,
    modifier: Modifier = Modifier,
    shimmerColor: Color = Color(0xFFB0B0B0),
    content: @Composable () -> Unit
) {
    if (isLoading) {
        val transition = rememberInfiniteTransition(label = "shimmer")
        val translateAnim by transition.animateFloat(
            initialValue = 0f,
            targetValue = 1000f,
            animationSpec = infiniteRepeatable(
                animation = tween(1200, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            ),
            label = "shimmer_translate"
        )
        
        Box(
            modifier = modifier
                .drawWithContent {
                    drawContent()
                    val brush = Brush.linearGradient(
                        colors = listOf(
                            shimmerColor.copy(alpha = 0f),
                            shimmerColor.copy(alpha = 0.5f),
                            shimmerColor.copy(alpha = 0f)
                        ),
                        start = Offset(translateAnim - 500f, 0f),
                        end = Offset(translateAnim, size.height)
                    )
                    drawRect(brush = brush, size = Size(size.width + 500f, size.height))
                }
        ) {
            content()
        }
    } else {
        content()
    }
}

@Composable
fun PulsingEffect(
    isPulsing: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    val transition = rememberInfiniteTransition(label = "pulse")
    val scale by transition.animateFloat(
        initialValue = 1f,
        targetValue = if (isPulsing) 1.05f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = EaseInOutQuad),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )
    
    Box(
        modifier = modifier.graphicsLayer {
            scaleX = scale
            scaleY = scale
        }
    ) {
        content()
    }
}

@Composable
fun BounceAnimation(
    isVisible: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    val transition = remember {
        MutableTransitionState(isVisible).apply {
            targetState = isVisible
        }
    }
    
    AnimatedVisibility(
        visibleState = transition,
        enter = scaleIn(
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessLow
            ),
            initialScale = 0.3f
        ) + fadeIn(),
        exit = scaleOut() + fadeOut(),
        modifier = modifier
    ) {
        content()
    }
}

@Composable
fun SlideInCard(
    visible: Boolean,
    delayMillis: Int = 0,
    content: @Composable () -> Unit
) {
    AnimatedVisibility(
        visible = visible,
        enter = slideInVertically(
            animationSpec = tween(400, delayMillis, EaseOutCubic),
            initialOffsetY = { it / 3 }
        ) + fadeIn(
            animationSpec = tween(400, delayMillis)
        ),
        exit = slideOutVertically() + fadeOut()
    ) {
        content()
    }
}

enum class AnimationType {
    FADE,
    SLIDE,
    SCALE,
    BOUNCE
}

@Composable
fun AnimatedContentView(
    targetState: Boolean,
    animationType: AnimationType = AnimationType.FADE,
    content: @Composable (Boolean) -> Unit
) {
    val enterTransition: EnterTransition = when (animationType) {
        AnimationType.FADE -> fadeIn(tween(300))
        AnimationType.SLIDE -> slideInVertically(tween(300)) + fadeIn(tween(300))
        AnimationType.SCALE -> scaleIn(tween(300)) + fadeIn(tween(300))
        AnimationType.BOUNCE -> scaleIn(
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessLow
            )
        ) + fadeIn()
    }
    
    val exitTransition: ExitTransition = when (animationType) {
        AnimationType.FADE -> fadeOut(tween(300))
        AnimationType.SLIDE -> slideOutVertically(tween(300)) + fadeOut(tween(300))
        AnimationType.SCALE -> scaleOut(tween(300)) + fadeOut(tween(300))
        AnimationType.BOUNCE -> scaleOut(tween(300)) + fadeOut(tween(300))
    }
    
    androidx.compose.animation.AnimatedContent(
        targetState = targetState,
        transitionSpec = {
            enterTransition togetherWith exitTransition
        },
        label = "animated_content"
    ) { state ->
        content(state)
    }
}