package com.studyapp.domain.model

import java.util.UUID

data class PendingSessionEvaluation(
    val id: UUID = UUID.randomUUID(),
    val session: StudySession
)
