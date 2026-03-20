package com.studyapp.presentation.materials

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.studyapp.domain.model.Material
import com.studyapp.presentation.scanner.BarcodeScannerScreen
import com.studyapp.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MaterialsScreen(
    viewModel: MaterialsViewModel = hiltViewModel(),
    onNavigateToSubjects: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
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
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                ),
                actions = {
                    IconButton(onClick = { showScanner = true }) {
                        Icon(
                            Icons.Default.QrCodeScanner,
                            contentDescription = stringResource(R.string.materials_scan_barcode),
                            tint = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                    TextButton(onClick = onNavigateToSubjects) {
                        Icon(
                            Icons.Default.Category,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.onPrimary
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = stringResource(R.string.materials_nav_subjects),
                            color = MaterialTheme.colorScheme.onPrimary
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
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator()
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = stringResource(R.string.common_loading),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
            uiState.materials.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            Icons.Default.Book,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = stringResource(R.string.materials_empty_title),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = stringResource(R.string.materials_empty_message),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
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
                        val subjectName = uiState.subjects.find { it.id == material.subjectId }?.name ?: ""
                        MaterialCard(
                            material = material,
                            subjectName = subjectName,
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
            onConfirm = { name, subjectId, totalPages ->
                viewModel.addMaterial(name, subjectId, totalPages)
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
            onConfirm = { name, subjectId, totalPages ->
                viewModel.updateMaterial(material.copy(
                    name = name,
                    subjectId = subjectId,
                    totalPages = totalPages
                ))
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
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onUpdateProgress: (Int) -> Unit
) {
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showProgressEdit by remember { mutableStateOf(false) }
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        onClick = { showProgressEdit = true }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = material.name,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = subjectName,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                
                Row {
                    IconButton(onClick = onEdit) {
                        Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.common_edit))
                    }
                    IconButton(onClick = { showDeleteConfirm = true }) {
                        Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.common_delete))
                    }
                }
            }
            
            if (material.totalPages > 0) {
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
                
                LinearProgressIndicator(
                    progress = { material.progress },
                    modifier = Modifier.fillMaxWidth()
                )
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