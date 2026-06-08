package com.studyapp.presentation.materials

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.studyapp.data.service.BookInfo
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemChapter
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.totalProblemCount
import java.util.UUID

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

                TextButton(onClick = onNavigateToSubjects) {
                    Icon(Icons.Default.Add, contentDescription = null)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("科目を追加")
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

private data class ProblemChapterDraft(
    val id: String = UUID.randomUUID().toString().lowercase(),
    val title: String = "",
    val problemCount: String = ""
)

private fun problemChaptersForSave(
    chapters: List<ProblemChapterDraft>,
    totalProblems: Int
): List<ProblemChapter> {
    val normalized = chapters.mapNotNull { draft ->
        val count = draft.problemCount.toIntOrNull() ?: 0
        val title = draft.title.trim()
        if (title.isEmpty() && count <= 0) return@mapNotNull null
        ProblemChapter(
            id = draft.id,
            title = title.ifEmpty { "章" },
            problemCount = count
        )
    }
    return normalized
}

private fun effectiveTotalProblems(
    chapters: List<ProblemChapter>,
    totalProblems: Int
): Int {
    val chapterTotal = chapters.totalProblemCount()
    return if (chapterTotal > 0) chapterTotal else totalProblems
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditMaterialDialog(
    material: Material? = null,
    subjects: List<Subject>,
    onDismiss: () -> Unit,
    onConfirm: (
        name: String,
        subjectId: Long,
        totalPages: Int,
        currentPage: Int,
        totalProblems: Int,
        problemChapters: List<ProblemChapter>,
        note: String
    ) -> Unit,
    onNavigateToSubjects: () -> Unit = {}
) {
    var name by remember { mutableStateOf(material?.name ?: "") }
    var selectedSubjectId by remember { mutableStateOf(material?.subjectId) }
    var totalPages by remember { mutableStateOf(material?.totalPages?.toString() ?: "") }
    var currentPage by remember { mutableStateOf(material?.currentPage?.toString() ?: "") }
    var totalProblems by remember {
        mutableStateOf(
            if (material?.problemChapters.isNullOrEmpty() == false) {
                ""
            } else {
                material?.totalProblems?.toString() ?: ""
            }
        )
    }
    var note by remember { mutableStateOf(material?.note ?: "") }
    var expanded by remember { mutableStateOf(false) }
    var problemChapters by remember {
        mutableStateOf(
            material?.problemChapters?.map { chapter ->
                ProblemChapterDraft(
                    id = chapter.id,
                    title = chapter.title,
                    problemCount = chapter.problemCount.toString()
                )
            }.orEmpty()
        )
    }
    val scrollState = rememberScrollState()
    val chapterTotal = problemChapters.sumOf { it.problemCount.toIntOrNull() ?: 0 }
    val displayedTotalProblems = if (chapterTotal > 0) chapterTotal.toString() else totalProblems
    
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
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 480.dp)
                    .verticalScroll(scrollState),
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

                TextButton(onClick = onNavigateToSubjects) {
                    Icon(Icons.Default.Add, contentDescription = null)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("科目を追加")
                }
                
                OutlinedTextField(
                    value = totalPages,
                    onValueChange = { totalPages = it.filter { c -> c.isDigit() } },
                    label = { Text("全ページ数（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = currentPage,
                    onValueChange = { currentPage = it.filter { c -> c.isDigit() } },
                    label = { Text("現在ページ（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = displayedTotalProblems,
                    onValueChange = {
                        if (problemChapters.isEmpty()) {
                            totalProblems = it.filter { c -> c.isDigit() }
                        }
                    },
                    readOnly = problemChapters.isNotEmpty(),
                    label = { Text("全問題数（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "章・節ごとの問題数",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                    problemChapters.forEachIndexed { index, chapter ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = chapter.title,
                                onValueChange = { value ->
                                    problemChapters = problemChapters.toMutableList().apply {
                                        set(index, chapter.copy(title = value))
                                    }
                                },
                                label = { Text("章名") },
                                modifier = Modifier.weight(1f),
                                singleLine = true
                            )
                            OutlinedTextField(
                                value = chapter.problemCount,
                                onValueChange = { value ->
                                    problemChapters = problemChapters.toMutableList().apply {
                                        set(index, chapter.copy(problemCount = value.filter { c -> c.isDigit() }))
                                    }
                                },
                                label = { Text("問数") },
                                modifier = Modifier.width(88.dp),
                                singleLine = true
                            )
                            IconButton(
                                onClick = {
                                    problemChapters = problemChapters.toMutableList().apply { removeAt(index) }
                                }
                            ) {
                                Icon(Icons.Default.Delete, contentDescription = "章を削除")
                            }
                        }
                    }
                    TextButton(
                        onClick = {
                            if (problemChapters.isEmpty()) {
                                val total = totalProblems.toIntOrNull()
                                problemChapters = listOf(
                                    ProblemChapterDraft(problemCount = total?.toString().orEmpty())
                                )
                                totalProblems = ""
                            } else {
                                problemChapters = problemChapters + ProblemChapterDraft()
                            }
                        }
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("章・節を追加")
                    }
                }

                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("メモ（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val pages = totalPages.toIntOrNull() ?: 0
                    val page = currentPage.toIntOrNull() ?: 0
                    val problems = totalProblems.toIntOrNull() ?: 0
                    val chapters = problemChaptersForSave(problemChapters, problems)
                    val effectiveProblems = effectiveTotalProblems(chapters, problems)
                    if (name.isNotBlank() && selectedSubjectId != null) {
                        onConfirm(
                            name.trim(),
                            selectedSubjectId!!,
                            pages,
                            page,
                            effectiveProblems,
                            chapters,
                            note.trim()
                        )
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
