package com.studyapp.data.local.db.entity

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation

@Entity(
    tableName = "study_sessions",
    foreignKeys = [
        ForeignKey(
            entity = MaterialEntity::class,
            parentColumns = ["id"],
            childColumns = ["materialId"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = SubjectEntity::class,
            parentColumns = ["id"],
            childColumns = ["subjectId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("materialId"), Index("subjectId"), Index("date"), Index("startTime")]
)
data class StudySessionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val materialId: Long?,
    val subjectId: Long,
    val startTime: Long,
    val endTime: Long,
    val duration: Long,
    val date: Long,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

data class StudySessionWithDetails(
    @Embedded val session: StudySessionEntity,
    @Relation(
        parentColumn = "subjectId",
        entityColumn = "id"
    )
    val subject: SubjectEntity?,
    @Relation(
        parentColumn = "materialId",
        entityColumn = "id"
    )
    val material: MaterialEntity?
)

data class StudySessionWithNames(
    @Embedded val session: StudySessionEntity,
    val subjectName: String,
    val materialName: String?
)