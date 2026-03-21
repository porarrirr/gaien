package com.studyapp.presentation.timer

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
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
    onDismiss: () -> Unit,
    onSelect: (Material, Subject) -> Unit
) {
    var selectedSubjectId by remember { mutableStateOf<Long?>(null) }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("教材を選択") },
        text = {
            LazyColumn {
                items(subjects) { subject ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        onClick = {
                            selectedSubjectId = if (selectedSubjectId == subject.id) null else subject.id
                        }
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text(
                                text = subject.name,
                                style = MaterialTheme.typography.titleMedium
                            )
                            
                            if (selectedSubjectId == subject.id) {
                                Spacer(modifier = Modifier.height(8.dp))
                                
                                val materials = materialsBySubject[subject.id] ?: emptyList()
                                
                                if (materials.isEmpty()) {
                                    Text(
                                        text = "教材がありません",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                } else {
                                    materials.forEach { material ->
                                        TextButton(
                                            onClick = { onSelect(material, subject) }
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
                Text("閉じる")
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
