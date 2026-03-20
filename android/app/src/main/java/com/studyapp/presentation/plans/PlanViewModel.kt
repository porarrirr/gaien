package com.studyapp.presentation.plans

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.*
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.usecase.ManagePlansUseCase
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import javax.inject.Inject

data class PlanUiState(
    val activePlan: StudyPlan? = null,
    val planItems: List<PlanItem> = emptyList(),
    val subjects: List<Subject> = emptyList(),
    val weeklySchedule: Map<DayOfWeek, List<PlanItemWithSubject>> = emptyMap(),
    val totalTargetMinutes: Int = 0,
    val totalActualMinutes: Int = 0,
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class PlanViewModel @Inject constructor(
    private val managePlansUseCase: ManagePlansUseCase,
    private val subjectRepository: SubjectRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(PlanUiState())
    val uiState: StateFlow<PlanUiState> = _uiState.asStateFlow()
    
    init {
        observeData()
    }
    
    private fun observeData() {
        viewModelScope.launch {
            subjectRepository.getAllSubjects()
                .combine(managePlansUseCase.getActivePlan()) { subjectsResult, plan ->
                    val subjects = when (subjectsResult) {
                        is Result.Success -> subjectsResult.data
                        is Result.Error -> {
                            _uiState.update { it.copy(
                                isLoading = false,
                                error = subjectsResult.message ?: subjectsResult.exception.message
                            )}
                            return@combine null
                        }
                    }
                    Pair(subjects, plan)
                }
                .filterNotNull()
                .flatMapLatest { (subjects, plan) ->
                    if (plan != null) {
                        managePlansUseCase.getPlanItems(plan.id).map { items ->
                            Triple(subjects, plan, items)
                        }
                    } else {
                        flowOf(Triple(subjects, null, emptyList()))
                    }
                }
                .collect { (subjects, plan, items) ->
                    val weeklySchedule = buildWeeklySchedule(items, subjects)
                    val totalTarget = items.sumOf { it.targetMinutes }
                    
                    _uiState.update { state ->
                        state.copy(
                            activePlan = plan,
                            planItems = items,
                            subjects = subjects,
                            weeklySchedule = weeklySchedule,
                            totalTargetMinutes = totalTarget,
                            isLoading = false,
                            error = null
                        )
                    }
                }
        }
    }
    
    private fun buildWeeklySchedule(
        items: List<PlanItem>,
        subjects: List<Subject>
    ): Map<DayOfWeek, List<PlanItemWithSubject>> {
        val subjectMap = subjects.associateBy { it.id }
        
        return DayOfWeek.entries.associateWith { day ->
            items
                .filter { it.dayOfWeek == day }
                .mapNotNull { item ->
                    subjectMap[item.subjectId]?.let { subject ->
                        PlanItemWithSubject(item, subject)
                    }
                }
        }
    }
    
    fun createPlan(name: String, startDate: Long, endDate: Long, items: List<PlanItem>) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            val plan = StudyPlan(
                name = name,
                startDate = startDate,
                endDate = endDate,
                createdAt = System.currentTimeMillis()
            )
            
            when (val result = managePlansUseCase.createPlan(plan, items)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun addPlanItem(subjectId: Long, dayOfWeek: DayOfWeek, targetMinutes: Int, timeSlot: String?) {
        viewModelScope.launch {
            val plan = _uiState.value.activePlan ?: return@launch
            
            _uiState.update { it.copy(isLoading = true) }
            
            val item = PlanItem(
                planId = plan.id,
                subjectId = subjectId,
                dayOfWeek = dayOfWeek,
                targetMinutes = targetMinutes,
                timeSlot = timeSlot
            )
            
            when (val result = managePlansUseCase.addPlanItem(item)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun updatePlanItem(item: PlanItem) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            when (val result = managePlansUseCase.updatePlanItem(item)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun deletePlanItem(item: PlanItem) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            when (val result = managePlansUseCase.deletePlanItem(item)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun deletePlan() {
        viewModelScope.launch {
            val plan = _uiState.value.activePlan ?: return@launch
            
            _uiState.update { it.copy(isLoading = true) }
            
            when (val result = managePlansUseCase.deletePlan(plan)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun getCompletionRate(): Float {
        val state = _uiState.value
        return if (state.totalTargetMinutes > 0) {
            state.totalActualMinutes.toFloat() / state.totalTargetMinutes.toFloat()
        } else 0f
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}