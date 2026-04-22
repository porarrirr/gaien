package com.studyapp.presentation.timer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.studyapp.R
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.Subject
import java.util.Calendar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MaterialPickerDialog(
    subjects: List<Subject>,
    materialsBySubject: Map<Long, List<Material>>,
    initialSubjectId: Long? = null,
    onDismiss: () -> Unit,
    onSelectSubject: (Subject) -> Unit,
    onSelectMaterial: (Material, Subject) -> Unit
) {
    var selectedSubjectId by remember(initialSubjectId, subjects) {
        mutableStateOf(initialSubjectId ?: subjects.firstOrNull()?.id)
    }
    val selectedSubject = remember(subjects, selectedSubjectId) {
        subjects.firstOrNull { it.id == selectedSubjectId }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.timer_select_subject)) },
        text = {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 360.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(subjects) { subject ->
                    ElevatedCard(
                        modifier = Modifier
                            .fillMaxWidth(),
                        onClick = {
                            selectedSubjectId = subject.id
                        },
                        colors = CardDefaults.elevatedCardColors(
                            containerColor = if (selectedSubjectId == subject.id) {
                                MaterialTheme.colorScheme.secondaryContainer
                            } else {
                                MaterialTheme.colorScheme.surface
                            }
                        )
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .padding(top = 4.dp)
                                        .size(12.dp)
                                        .clip(CircleShape)
                                        .background(Color(subject.color))
                                )
                                Column(
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text(
                                        text = subject.name,
                                        style = MaterialTheme.typography.titleMedium
                                    )
                                }
                            }

                            if (selectedSubjectId == subject.id) {
                                val materials = materialsBySubject[subject.id].orEmpty()

                                HorizontalDivider(
                                    modifier = Modifier.padding(vertical = 12.dp)
                                )

                                if (materials.isEmpty()) {
                                    Text(
                                        text = stringResource(R.string.timer_subject_has_no_materials),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                } else {
                                    Text(
                                        text = stringResource(R.string.timer_select_material),
                                        style = MaterialTheme.typography.labelLarge,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )

                                    Spacer(modifier = Modifier.height(8.dp))

                                    materials.forEach { material ->
                                        TextButton(
                                            onClick = { onSelectMaterial(material, subject) },
                                            modifier = Modifier.fillMaxWidth(),
                                            contentPadding = PaddingValues(horizontal = 0.dp)
                                        ) {
                                            Text(material.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { selectedSubject?.let(onSelectSubject) },
                enabled = selectedSubject != null
            ) {
                Text(stringResource(R.string.timer_select_subject_only))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.common_close))
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ManualInputDialog(
    subjects: List<Subject>,
    initialSubjectId: Long? = null,
    onDismiss: () -> Unit,
    onConfirm: (subjectId: Long, materialId: Long?, startTime: Long, endTime: Long) -> Unit
) {
    val now = remember {
        Calendar.getInstance()
    }
    var startText by remember {
        mutableStateOf(
            String.format(
                "%02d:%02d",
                now.get(Calendar.HOUR_OF_DAY),
                0
            )
        )
    }
    var endText by remember {
        mutableStateOf(
            String.format(
                "%02d:%02d",
                now.get(Calendar.HOUR_OF_DAY),
                now.get(Calendar.MINUTE)
            )
        )
    }
    var selectedSubjectId by remember(initialSubjectId) { mutableStateOf(initialSubjectId) }
    var isSubjectMenuExpanded by remember { mutableStateOf(false) }
    val selectedSubject = remember(subjects, selectedSubjectId) {
        subjects.firstOrNull { it.id == selectedSubjectId }
    }
    val startTime = remember(startText) { parseTodayTime(startText) }
    val endTime = remember(endText) { parseTodayTime(endText) }
    val isTimeRangeValid = startTime != null && endTime != null && endTime > startTime

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.timer_manual_input_title)) },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                ExposedDropdownMenuBox(
                    expanded = isSubjectMenuExpanded,
                    onExpandedChange = { isSubjectMenuExpanded = it }
                ) {
                    OutlinedTextField(
                        value = selectedSubject?.name ?: "",
                        onValueChange = {},
                        label = { Text(stringResource(R.string.timer_select_subject)) },
                        readOnly = true,
                        enabled = subjects.isNotEmpty(),
                        trailingIcon = {
                            ExposedDropdownMenuDefaults.TrailingIcon(expanded = isSubjectMenuExpanded)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )

                    ExposedDropdownMenu(
                        expanded = isSubjectMenuExpanded,
                        onDismissRequest = { isSubjectMenuExpanded = false }
                    ) {
                        subjects.forEach { subject ->
                            DropdownMenuItem(
                                text = { Text(subject.name) },
                                onClick = {
                                    selectedSubjectId = subject.id
                                    isSubjectMenuExpanded = false
                                }
                            )
                        }
                    }
                }

                if (subjects.isEmpty()) {
                    Text(
                        text = "先に科目を追加してください",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                OutlinedTextField(
                    value = startText,
                    onValueChange = { startText = it.take(5) },
                    label = { Text(stringResource(R.string.timer_start_time)) },
                    supportingText = { Text(stringResource(R.string.timer_time_format_hint)) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = endText,
                    onValueChange = { endText = it.take(5) },
                    label = { Text(stringResource(R.string.timer_end_time)) },
                    supportingText = { Text(stringResource(R.string.timer_time_format_hint)) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val subjectId = selectedSubjectId
                    if (subjectId != null && startTime != null && endTime != null && endTime > startTime) {
                        onConfirm(subjectId, null, startTime, endTime)
                    }
                },
                enabled = selectedSubjectId != null && isTimeRangeValid
            ) {
                Text(stringResource(R.string.common_save))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.common_cancel))
            }
        }
    )
}

private fun parseTodayTime(value: String): Long? {
    val match = Regex("""^(\d{1,2}):(\d{2})$""").matchEntire(value.trim()) ?: return null
    val hour = match.groupValues[1].toIntOrNull() ?: return null
    val minute = match.groupValues[2].toIntOrNull() ?: return null
    if (hour !in 0..23 || minute !in 0..59) {
        return null
    }
    return Calendar.getInstance().run {
        set(Calendar.HOUR_OF_DAY, hour)
        set(Calendar.MINUTE, minute)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        timeInMillis
    }
}
