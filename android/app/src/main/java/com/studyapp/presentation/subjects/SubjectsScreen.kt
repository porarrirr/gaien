package com.studyapp.presentation.subjects

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Biotech
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.BubbleChart
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.SubjectIcon
import com.studyapp.presentation.components.EmptyState
import com.studyapp.presentation.components.ErrorState
import com.studyapp.presentation.components.LoadingState
import com.studyapp.presentation.theme.toSubjectColor
import java.util.Locale

private val SubjectCardBorder = Color(0xFFE5E7EB)
private val SubjectSuccess = Color(0xFF2EA44F)
private val SubjectSoftBackground = Color(0xFFF6F8FA)
private val SubjectDanger = Color(0xFFFF2D2D)

private val SubjectEditorPresetColors: List<Int> = listOf(
    0x4CAF50,
    0x2196F3,
    0xFF9800,
    0xF44336,
    0x9C27B0,
    0x00BCD4,
    0xE91E63,
    0x795548,
    0x607D8B,
    0x3F51B5,
    0x009688,
    0xFFC107
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubjectsScreen(
    viewModel: SubjectsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showAddSheet by remember { mutableStateOf(false) }
    var editingSubject by remember { mutableStateOf<Subject?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "科目",
                        fontSize = 29.sp,
                        fontWeight = FontWeight.Bold
                    )
                },
                actions = {
                    IconButton(onClick = { showAddSheet = true }) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "科目を追加",
                            tint = SubjectSuccess,
                            modifier = Modifier.size(34.dp)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                LoadingState(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    message = "読み込み中..."
                )
            }

            uiState.error != null -> {
                ErrorState(
                    message = uiState.error ?: "エラーが発生しました",
                    onRetry = { viewModel.clearError() },
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                )
            }

            uiState.subjects.isEmpty() -> {
                EmptyState(
                    icon = Icons.Default.Category,
                    title = "科目がありません",
                    description = "右上の＋ボタンから科目を追加してください。",
                    actionLabel = "科目を追加",
                    onAction = { showAddSheet = true },
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                )
            }

            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(SubjectSoftBackground)
                        .padding(paddingValues),
                    contentPadding = PaddingValues(start = 15.dp, top = 23.dp, end = 15.dp, bottom = 28.dp),
                    verticalArrangement = Arrangement.spacedBy(18.dp)
                ) {
                    item {
                        Text(
                            text = "科目一覧",
                            modifier = Modifier.padding(start = 3.dp),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    item {
                        SubjectListCard(
                            subjects = uiState.subjects,
                            onEdit = { editingSubject = it },
                            onDelete = { viewModel.deleteSubject(it) }
                        )
                    }
                    item {
                        SubjectInfoCard()
                    }
                }
            }
        }
    }

    if (showAddSheet) {
        SubjectEditorSheet(
            title = "科目を追加",
            initialSubject = null,
            onDismiss = { showAddSheet = false },
            onSave = { name, color, icon ->
                viewModel.addSubject(name, color, icon)
                showAddSheet = false
            }
        )
    }

    editingSubject?.let { subject ->
        SubjectEditorSheet(
            title = "科目を編集",
            initialSubject = subject,
            onDismiss = { editingSubject = null },
            onSave = { name, color, icon ->
                viewModel.updateSubject(subject.copy(name = name, color = color, icon = icon))
                editingSubject = null
            }
        )
    }
}

@Composable
private fun SubjectListCard(
    subjects: List<Subject>,
    onEdit: (Subject) -> Unit,
    onDelete: (Subject) -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, SubjectCardBorder)
    ) {
        Column {
            subjects.forEachIndexed { index, subject ->
                SubjectRow(
                    subject = subject,
                    onEdit = { onEdit(subject) },
                    onDelete = { onDelete(subject) }
                )
                if (index < subjects.lastIndex) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 66.dp),
                        color = SubjectCardBorder
                    )
                }
            }
        }
    }
}

@Composable
private fun SubjectRow(
    subject: Subject,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    val subjectColor = subject.color.toSubjectColor()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(subjectColor),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = (subject.icon ?: SubjectIcon.BOOK).imageVector,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(21.dp)
            )
        }

        Text(
            text = subject.name,
            modifier = Modifier
                .weight(1f)
                .padding(start = 14.dp),
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        Box(
            modifier = Modifier
                .width(42.dp)
                .padding(horizontal = 14.dp),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(13.dp)
                    .clip(CircleShape)
                    .background(subjectColor)
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SubjectRowAction(
                label = "編集",
                icon = Icons.Default.Edit,
                color = SubjectSuccess,
                onClick = onEdit
            )
            SubjectRowAction(
                label = "削除",
                icon = Icons.Default.Delete,
                color = SubjectDanger,
                onClick = onDelete
            )
        }
    }
}

@Composable
private fun SubjectRowAction(
    label: String,
    icon: ImageVector,
    color: Color,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = color,
            modifier = Modifier.size(15.dp)
        )
        Text(
            text = label,
            color = color,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun SubjectInfoCard() {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, SubjectCardBorder)
    ) {
        Text(
            text = "科目はタイマー、計画、レポートの選択肢として利用されます。",
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 18.dp),
            fontSize = 15.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 2
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun SubjectEditorSheet(
    title: String,
    initialSubject: Subject?,
    onDismiss: () -> Unit,
    onSave: (name: String, color: Int, icon: SubjectIcon) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var name by remember(initialSubject?.id) { mutableStateOf(initialSubject?.name ?: "") }
    var colorHex by remember(initialSubject?.id) {
        mutableStateOf((initialSubject?.color ?: 0x4CAF50).toColorHex())
    }
    var selectedIcon by remember(initialSubject?.id) {
        mutableStateOf(initialSubject?.icon ?: SubjectIcon.BOOK)
    }
    val parsedColor = parseColorHex(colorHex)
    val canSave = name.trim().isNotEmpty() && parsedColor != null

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SubjectSoftBackground,
        dragHandle = { BottomSheetDefaults.DragHandle() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            SheetHeader(
                title = title,
                confirmLabel = "保存",
                confirmEnabled = canSave,
                onCancel = onDismiss,
                onConfirm = {
                    val color = parsedColor ?: return@SheetHeader
                    onSave(name.trim(), color, selectedIcon)
                }
            )

            EditorSectionCard(
                title = "科目名",
                icon = Icons.Default.Book
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("例）数学III") },
                    singleLine = true
                )
            }

            EditorSectionCard(
                title = "色",
                icon = Icons.Default.Palette
            ) {
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    SubjectEditorPresetColors.forEach { color ->
                        val isSelected = parsedColor == color
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(color.toSubjectColor())
                                .then(
                                    if (isSelected) {
                                        Modifier.border(2.dp, MaterialTheme.colorScheme.onSurface, CircleShape)
                                    } else {
                                        Modifier
                                    }
                                )
                                .clickable {
                                    colorHex = color.toColorHex()
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            if (isSelected) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = "選択中",
                                    tint = Color.White,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "カスタム色",
                        modifier = Modifier.width(96.dp),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    OutlinedTextField(
                        value = colorHex,
                        onValueChange = { colorHex = it },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        isError = parsedColor == null,
                        placeholder = { Text("#4CAF50") }
                    )
                    Box(
                        modifier = Modifier
                            .size(34.dp)
                            .clip(CircleShape)
                            .background((parsedColor ?: 0x4CAF50).toSubjectColor())
                    )
                }
            }

            EditorSectionCard(
                title = "アイコン",
                icon = Icons.Default.Category
            ) {
                var expanded by remember { mutableStateOf(false) }
                Box {
                    OutlinedButton(
                        onClick = { expanded = true },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.onSurface)
                    ) {
                        Icon(
                            imageVector = selectedIcon.imageVector,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = selectedIcon.japaneseLabel,
                            modifier = Modifier.weight(1f),
                            fontSize = 16.sp
                        )
                        Icon(
                            imageVector = Icons.Default.KeyboardArrowDown,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    androidx.compose.material3.DropdownMenu(
                        expanded = expanded,
                        onDismissRequest = { expanded = false }
                    ) {
                        SubjectIcon.values().forEach { icon: SubjectIcon ->
                            androidx.compose.material3.DropdownMenuItem(
                                text = { Text(icon.japaneseLabel) },
                                leadingIcon = {
                                    Icon(
                                        imageVector = icon.imageVector,
                                        contentDescription = null
                                    )
                                },
                                onClick = {
                                    selectedIcon = icon
                                    expanded = false
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SheetHeader(
    title: String,
    confirmLabel: String,
    confirmEnabled: Boolean,
    onCancel: () -> Unit,
    onConfirm: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TextButton(onClick = onCancel) {
            Text(
                text = "キャンセル",
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = SubjectSuccess
            )
        }
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            fontSize = 21.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        TextButton(
            enabled = confirmEnabled,
            onClick = onConfirm
        ) {
            Text(
                text = confirmLabel,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun EditorSectionCard(
    title: String,
    icon: ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, SubjectCardBorder)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = SubjectSuccess,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = title,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
            content()
        }
    }
}

private val SubjectIcon.imageVector: ImageVector
    get() = when (this) {
        SubjectIcon.BOOK -> Icons.Default.Book
        SubjectIcon.CALCULATOR -> Icons.Default.Calculate
        SubjectIcon.FLASK -> Icons.Default.Science
        SubjectIcon.GLOBE -> Icons.Default.Public
        SubjectIcon.PALETTE -> Icons.Default.Palette
        SubjectIcon.MUSIC -> Icons.Default.MusicNote
        SubjectIcon.CODE -> Icons.Default.Code
        SubjectIcon.ATOM -> Icons.Default.BubbleChart
        SubjectIcon.DNA -> Icons.Default.Biotech
        SubjectIcon.BRAIN -> Icons.Default.Psychology
        SubjectIcon.LANGUAGE -> Icons.Default.Translate
        SubjectIcon.HISTORY -> Icons.Default.History
        SubjectIcon.OTHER -> Icons.Default.Category
    }

private val SubjectIcon.japaneseLabel: String
    get() = when (this) {
        SubjectIcon.BOOK -> "本"
        SubjectIcon.CALCULATOR -> "計算"
        SubjectIcon.FLASK -> "実験"
        SubjectIcon.GLOBE -> "地理"
        SubjectIcon.PALETTE -> "美術"
        SubjectIcon.MUSIC -> "音楽"
        SubjectIcon.CODE -> "コード"
        SubjectIcon.ATOM -> "物理"
        SubjectIcon.DNA -> "生物"
        SubjectIcon.BRAIN -> "心理"
        SubjectIcon.LANGUAGE -> "言語"
        SubjectIcon.HISTORY -> "歴史"
        SubjectIcon.OTHER -> "その他"
    }

private fun Int.toColorHex(): String {
    return "#%06X".format(Locale.US, this and 0x00FFFFFF)
}

private fun parseColorHex(input: String): Int? {
    val raw = input.trim().removePrefix("#")
    if (raw.length != 6 || raw.any { it !in '0'..'9' && it !in 'a'..'f' && it !in 'A'..'F' }) {
        return null
    }
    return raw.toInt(16)
}
