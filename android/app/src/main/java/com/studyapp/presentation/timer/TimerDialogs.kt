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

                                    Spacer(modifier = Modifier.height(8.dp))

                                    TextButton(
                                        onClick = { onSelectSubject(subject) },
                                        contentPadding = PaddingValues(0.dp)
                                    ) {
                                        Text(stringResource(R.string.timer_select_subject_only))
                                    }
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
    onConfirm: (subjectId: Long, materialId: Long?, durationMinutes: Long) -> Unit
) {
    var duration by remember { mutableStateOf("") }
    var selectedSubjectId by remember(initialSubjectId) { mutableStateOf(initialSubjectId) }
    var isSubjectMenuExpanded by remember { mutableStateOf(false) }
    val selectedSubject = remember(subjects, selectedSubjectId) {
        subjects.firstOrNull { it.id == selectedSubjectId }
    }

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
                    value = duration,
                    onValueChange = { duration = it.filter { c -> c.isDigit() } },
                    label = { Text(stringResource(R.string.timer_duration)) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val subjectId = selectedSubjectId
                    val durationMinutes = duration.toLongOrNull() ?: 0L
                    if (subjectId != null && durationMinutes > 0) {
                        onConfirm(subjectId, null, durationMinutes)
                    }
                },
                enabled = duration.isNotEmpty() && selectedSubjectId != null
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
