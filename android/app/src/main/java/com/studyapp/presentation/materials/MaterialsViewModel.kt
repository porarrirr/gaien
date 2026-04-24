package com.studyapp.presentation.materials

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.data.service.BookInfo
import com.studyapp.data.service.GoogleBooksService
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.usecase.ManageMaterialsUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class MaterialsUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val materials: List<Material> = emptyList(),
    val subjects: List<Subject> = emptyList(),
    val hasSubjects: Boolean = false,
    val searchResult: BookInfo? = null
)

@HiltViewModel
class MaterialsViewModel @Inject constructor(
    private val manageMaterialsUseCase: ManageMaterialsUseCase,
    private val subjectRepository: SubjectRepository,
    private val googleBooksService: GoogleBooksService
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(MaterialsUiState())
    val uiState: StateFlow<MaterialsUiState> = _uiState.asStateFlow()
    
    init {
        loadData()
    }
    
    private fun loadData() {
        combine(
            manageMaterialsUseCase.getAllMaterials(),
            subjectRepository.getAllSubjects()
        ) { materials, subjectsResult ->
            val subjects = subjectsResult.getOrNull() ?: emptyList()
            MaterialsUiState(
                isLoading = false,
                error = null,
                materials = materials,
                subjects = subjects,
                hasSubjects = subjects.isNotEmpty()
            )
        }
        .onEach { state ->
            _uiState.update { currentState ->
                state.copy(searchResult = currentState.searchResult)
            }
        }
        .catch { e ->
            _uiState.update { state ->
                state.copy(
                    isLoading = false,
                    error = e.message ?: "データの読み込みに失敗しました"
                )
            }
        }
        .launchIn(viewModelScope)
    }
    
    fun addMaterial(name: String, subjectId: Long, totalPages: Int) {
        viewModelScope.launch {
            val subjectSyncId = _uiState.value.subjects.firstOrNull { it.id == subjectId }?.syncId
            manageMaterialsUseCase.addMaterial(
                Material(
                    name = name,
                    subjectId = subjectId,
                    subjectSyncId = subjectSyncId,
                    sortOrder = (_uiState.value.materials.maxOfOrNull { it.sortOrder } ?: -1L) + 1L,
                    totalPages = totalPages
                )
            ).onError { error ->
                _uiState.update { it.copy(error = error.message ?: "教材の追加に失敗しました") }
            }
        }
    }
    
    fun updateMaterial(material: Material) {
        viewModelScope.launch {
            val subjectSyncId = _uiState.value.subjects.firstOrNull { it.id == material.subjectId }?.syncId
            manageMaterialsUseCase.updateMaterial(material.copy(subjectSyncId = subjectSyncId))
                .onError { error ->
                    _uiState.update { it.copy(error = error.message ?: "教材の更新に失敗しました") }
                }
        }
    }
    
    fun deleteMaterial(material: Material) {
        viewModelScope.launch {
            manageMaterialsUseCase.deleteMaterial(material)
                .onError { error ->
                    _uiState.update { it.copy(error = error.message ?: "教材の削除に失敗しました") }
                }
        }
    }
    
    fun updateProgress(id: Long, page: Int) {
        viewModelScope.launch {
            manageMaterialsUseCase.updateProgress(id, page)
                .onError { error ->
                    _uiState.update { it.copy(error = error.message ?: "進捗の更新に失敗しました") }
                }
        }
    }
    
    fun searchBookByIsbn(isbn: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            googleBooksService.searchByIsbn(isbn)
                .onSuccess { bookInfo ->
                    _uiState.update { it.copy(
                        searchResult = bookInfo,
                        isLoading = false
                    )}
                }
                .onFailure { error ->
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = error.message ?: "書籍情報の取得に失敗しました"
                    )}
                }
        }
    }
    
    fun clearSearchResult() {
        _uiState.update { it.copy(searchResult = null) }
    }

    fun moveMaterial(materialId: Long, direction: Int) {
        viewModelScope.launch {
            val materials = _uiState.value.materials
            val currentIndex = materials.indexOfFirst { it.id == materialId }
            if (currentIndex == -1) return@launch
            val targetIndex = currentIndex + direction
            if (targetIndex !in materials.indices) return@launch

            val reordered = materials.toMutableList().apply {
                add(targetIndex, removeAt(currentIndex))
            }
            val result = manageMaterialsUseCase.updateOrder(reordered.map { it.id })
            result.onError { error ->
                _uiState.update { it.copy(error = error.message ?: "教材順の更新に失敗しました") }
            }
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
