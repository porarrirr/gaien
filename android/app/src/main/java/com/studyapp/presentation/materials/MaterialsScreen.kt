package com.studyapp.presentation.materials

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.MaterialListProgressSummary
import com.studyapp.presentation.scanner.BarcodeScannerScreen
import com.studyapp.R
import com.studyapp.presentation.components.AnimatedProgressBar
import com.studyapp.presentation.components.EmptyState
import com.studyapp.presentation.components.LoadingState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MaterialsScreen(
    viewModel: MaterialsViewModel = hiltViewModel(),
    onNavigateToSubjects: () -> Unit = {},
    onOpenMaterialHistory: (Long) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showAddDialog by remember { mutableStateOf(false) }
    var editingMaterial by remember { mutableStateOf<Material?>(null) }
    var showScanner by remember { mutableStateOf(false) }
    var showBookSearchDialog by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }
    
    var previousSearchResult by remember { mutableStateOf<com.studyapp.data.service.BookInfo?>(null) }
    
    LaunchedEffect(uiState.searchResult) {
        val currentResult = uiState.searchResult
        if (currentResult != null && currentResult != previousSearchResult) {
            showBookSearchDialog = true
            previousSearchResult = currentResult
        }
    }
    
    LaunchedEffect(uiState.error) {
        uiState.error?.let { error ->
            snackbarHostState.showSnackbar(error)
            viewModel.clearError()
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = stringResource(R.string.materials_screen_title),
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    IconButton(onClick = { showScanner = true }) {
                        Icon(
                            Icons.Default.QrCodeScanner,
                            contentDescription = stringResource(R.string.materials_scan_barcode),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    TextButton(onClick = onNavigateToSubjects) {
                        Icon(
                            Icons.Default.Category,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = stringResource(R.string.materials_nav_subjects),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddDialog = true },
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, contentDescription = stringResource(R.string.common_add))
            }
        },
        bottomBar = {
            if (!uiState.isLoading && uiState.subjects.isEmpty()) {
                androidx.compose.material3.Surface(
                    modifier = Modifier.fillMaxWidth(),
                    color = MaterialTheme.colorScheme.primaryContainer,
                    shadowElevation = 4.dp
                ) {
                    Button(
                        onClick = onNavigateToSubjects,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Text("先に科目を作成")
                    }
                }
            }
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                LoadingState(
                    modifier = Modifier.padding(paddingValues),
                    message = stringResource(R.string.common_loading)
                )
            }
            uiState.materials.isEmpty() -> {
                EmptyState(
                    icon = Icons.Default.Book,
                    title = stringResource(R.string.materials_empty_title),
                    description = stringResource(R.string.materials_empty_message),
                    modifier = Modifier.padding(paddingValues)
                )
            }
            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(uiState.materials, key = { it.id }) { material ->
                        val subject = remember(material.subjectId, uiState.subjects) {
                            uiState.subjects.find { it.id == material.subjectId }
                        }
                        MaterialCard(
                            material = material,
                            subjectName = subject?.name ?: "",
                            subjectColor = subject?.color ?: 0xFF4CAF50.toInt(),
                            progressSummary = uiState.progressSummaries[material.id],
                            canMoveUp = uiState.materials.firstOrNull()?.id != material.id,
                            canMoveDown = uiState.materials.lastOrNull()?.id != material.id,
                            onOpenHistory = { onOpenMaterialHistory(material.id) },
                            onMoveUp = { viewModel.moveMaterial(material.id, -1) },
                            onMoveDown = { viewModel.moveMaterial(material.id, 1) },
                            onEdit = { editingMaterial = material },
                            onDelete = { viewModel.deleteMaterial(material) },
                            onUpdateProgress = { page ->
                                viewModel.updateProgress(material.id, page)
                            }
                        )
                    }
                }
            }
        }
    }
    
    if (showAddDialog) {
        AddEditMaterialDialog(
            subjects = uiState.subjects,
            onDismiss = { showAddDialog = false },
            onConfirm = { name, subjectId, totalPages, currentPage, totalProblems, problemChapters, note ->
                viewModel.addMaterial(
                    name = name,
                    subjectId = subjectId,
                    totalPages = totalPages,
                    currentPage = currentPage,
                    totalProblems = totalProblems,
                    problemChapters = problemChapters,
                    note = note
                )
                showAddDialog = false
            },
            onNavigateToSubjects = {
                showAddDialog = false
                onNavigateToSubjects()
            }
        )
    }
    
    editingMaterial?.let { material ->
        AddEditMaterialDialog(
            material = material,
            subjects = uiState.subjects,
            onDismiss = { editingMaterial = null },
            onConfirm = { name, subjectId, totalPages, currentPage, totalProblems, problemChapters, note ->
                viewModel.updateMaterial(
                    material.copy(
                        name = name,
                        subjectId = subjectId,
                        totalPages = totalPages,
                        currentPage = currentPage,
                        totalProblems = totalProblems,
                        problemChapters = problemChapters,
                        note = note.takeIf { it.isNotBlank() }
                    )
                )
                editingMaterial = null
            },
            onNavigateToSubjects = {
                editingMaterial = null
                onNavigateToSubjects()
            }
        )
    }
    
    if (showScanner) {
        BarcodeScannerScreen(
            onBarcodeScanned = { isbn ->
                viewModel.searchBookByIsbn(isbn)
            },
            onDismiss = { showScanner = false }
        )
    }
    
    uiState.searchResult?.let { bookInfo ->
        if (showBookSearchDialog) {
            BookSearchResultDialog(
                bookInfo = bookInfo,
                subjects = uiState.subjects,
                onDismiss = {
                    showBookSearchDialog = false
                    viewModel.clearSearchResult()
                    previousSearchResult = null
                },
                onConfirm = { name, subjectId, totalPages ->
                    viewModel.addMaterial(name, subjectId, totalPages)
                    showBookSearchDialog = false
                    viewModel.clearSearchResult()
                    previousSearchResult = null
                },
                onNavigateToSubjects = {
                    showBookSearchDialog = false
                    viewModel.clearSearchResult()
                    previousSearchResult = null
                    onNavigateToSubjects()
                }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MaterialCard(
    material: Material,
    subjectName: String,
    subjectColor: Int = 0xFF4CAF50.toInt(),
    progressSummary: MaterialListProgressSummary?,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onOpenHistory: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onUpdateProgress: (Int) -> Unit
) {
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showProgressEdit by remember { mutableStateOf(false) }
    val accentColor = Color(material.color ?: subjectColor)
    val hasProblemTracking = material.effectiveTotalProblems > 0

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onOpenHistory
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        SubjectColorDot(color = subjectColor)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = subjectName.ifEmpty { "科目なし" },
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = material.name,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Row {
                    IconButton(onClick = onMoveUp, enabled = canMoveUp) {
                        Icon(Icons.Default.KeyboardArrowUp, contentDescription = "上へ")
                    }
                    IconButton(onClick = onMoveDown, enabled = canMoveDown) {
                        Icon(Icons.Default.KeyboardArrowDown, contentDescription = "下へ")
                    }
                    IconButton(onClick = { showDeleteConfirm = true }) {
                        Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.common_delete))
                    }
                }
            }

            if (hasProblemTracking && progressSummary != null) {
                Spacer(modifier = Modifier.height(10.dp))
                MaterialProblemProgressSection(
                    totalProblems = material.effectiveTotalProblems,
                    chapterCount = material.problemChapters.size,
                    summary = progressSummary,
                    accentColor = accentColor
                )
            } else if (material.totalPages > 0) {
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(R.string.materials_page_progress, material.currentPage, material.totalPages),
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = stringResource(R.string.materials_percent, material.progressPercent),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                AnimatedProgressBar(
                    progress = material.progress.toFloat(),
                    modifier = Modifier.fillMaxWidth(),
                    height = 10.dp,
                    progressColor = accentColor
                )
            }

            HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = onOpenHistory) {
                    Text("履歴")
                }
                TextButton(onClick = onEdit) {
                    Text(stringResource(R.string.common_edit))
                }
                if (material.totalPages > 0) {
                    TextButton(onClick = { showProgressEdit = true }) {
                        Text("進捗更新")
                    }
                }
            }
        }
    }
    
    if (showDeleteConfirm) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(stringResource(R.string.materials_delete_title)) },
            text = { Text(stringResource(R.string.materials_delete_message, material.name)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        onDelete()
                        showDeleteConfirm = false
                    }
                ) {
                    Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            }
        )
    }
    
    if (showProgressEdit) {
        ProgressEditDialog(
            currentPage = material.currentPage,
            totalPages = material.totalPages,
            onDismiss = { showProgressEdit = false },
            onConfirm = { page ->
                onUpdateProgress(page)
                showProgressEdit = false
            }
        )
    }
}
