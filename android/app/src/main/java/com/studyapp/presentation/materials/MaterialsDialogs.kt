package com.studyapp.presentation.materials

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.studyapp.data.service.BookInfo
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.Subject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookSearchResultDialog(
    bookInfo: BookInfo,
    subjects: List<Subject>,
    onDismiss: () -> Unit,
    onConfirm: (name: String, subjectId: Long, totalPages: Int) -> Unit,
    onNavigateToSubjects: () -> Unit = {}
) {
    var selectedSubjectId by remember { mutableStateOf<Long?>(null) }
    var expanded by remember { mutableStateOf(false) }
    
    val totalPages = bookInfo.pageCount ?: 0
    
    if (subjects.isEmpty()) {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("科目がありません") },
            text = {
                Column {
                    Text("教材を追加するには、まず科目を登録してください。")
                }
            },
            confirmButton = {
                TextButton(onClick = onNavigateToSubjects) {
                    Text("科目を追加")
                }
            },
            dismissButton = {
                TextButton(onClick = onDismiss) {
                    Text("キャンセル")
                }
            }
        )
        return
    }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("書籍情報") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp)
                    ) {
                        Text(
                            text = bookInfo.title,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        
                        if (bookInfo.authors.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = bookInfo.authors.joinToString(", "),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        
                        bookInfo.publisher?.let { publisher ->
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "出版社: $publisher",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        
                        if (totalPages > 0) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "全${totalPages}ページ",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
                
                ExposedDropdownMenuBox(
                    expanded = expanded,
                    onExpandedChange = { expanded = it }
                ) {
                    OutlinedTextField(
                        value = subjects.find { it.id == selectedSubjectId }?.name ?: "科目を選択",
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = {
                            ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
                        },
                        label = { Text("科目") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    
                    ExposedDropdownMenu(
                        expanded = expanded,
                        onDismissRequest = { expanded = false }
                    ) {
                        subjects.forEach { subject ->
                            DropdownMenuItem(
                                text = { Text(subject.name) },
                                onClick = {
                                    selectedSubjectId = subject.id
                                    expanded = false
                                }
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (selectedSubjectId != null) {
                        onConfirm(bookInfo.title, selectedSubjectId!!, totalPages)
                    }
                },
                enabled = selectedSubjectId != null
            ) {
                Text("教材として追加")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditMaterialDialog(
    material: Material? = null,
    subjects: List<Subject>,
    onDismiss: () -> Unit,
    onConfirm: (name: String, subjectId: Long, totalPages: Int) -> Unit,
    onNavigateToSubjects: () -> Unit = {}
) {
    var name by remember { mutableStateOf(material?.name ?: "") }
    var selectedSubjectId by remember { mutableStateOf(material?.subjectId) }
    var totalPages by remember { mutableStateOf(material?.totalPages?.toString() ?: "") }
    var expanded by remember { mutableStateOf(false) }
    
    if (subjects.isEmpty()) {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("科目がありません") },
            text = {
                Column {
                    Text("教材を追加するには、まず科目を登録してください。")
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "科目を登録すると、教材を科目ごとに整理できます。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = onNavigateToSubjects) {
                    Text("科目を追加")
                }
            },
            dismissButton = {
                TextButton(onClick = onDismiss) {
                    Text("キャンセル")
                }
            }
        )
        return
    }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (material == null) "教材を追加" else "教材を編集") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("教材名") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                
                ExposedDropdownMenuBox(
                    expanded = expanded,
                    onExpandedChange = { expanded = it }
                ) {
                    OutlinedTextField(
                        value = subjects.find { it.id == selectedSubjectId }?.name ?: "科目を選択",
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = {
                            ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    
                    ExposedDropdownMenu(
                        expanded = expanded,
                        onDismissRequest = { expanded = false }
                    ) {
                        subjects.forEach { subject ->
                            DropdownMenuItem(
                                text = { Text(subject.name) },
                                onClick = {
                                    selectedSubjectId = subject.id
                                    expanded = false
                                }
                            )
                        }
                    }
                }
                
                OutlinedTextField(
                    value = totalPages,
                    onValueChange = { totalPages = it.filter { c -> c.isDigit() } },
                    label = { Text("全ページ数（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val pages = totalPages.toIntOrNull() ?: 0
                    if (name.isNotBlank() && selectedSubjectId != null) {
                        onConfirm(name, selectedSubjectId!!, pages)
                    }
                },
                enabled = name.isNotBlank() && selectedSubjectId != null
            ) {
                Text("保存")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}

@Composable
fun ProgressEditDialog(
    currentPage: Int,
    totalPages: Int,
    onDismiss: () -> Unit,
    onConfirm: (Int) -> Unit
) {
    var page by remember { mutableStateOf(currentPage.toString()) }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("進捗を更新") },
        text = {
            Column {
                OutlinedTextField(
                    value = page,
                    onValueChange = { page = it.filter { c -> c.isDigit() } },
                    label = { Text("現在のページ") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                
                if (totalPages > 0) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "全${totalPages}ページ",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val pageInt = page.toIntOrNull() ?: 0
                    onConfirm(pageInt)
                }
            ) {
                Text("更新")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}