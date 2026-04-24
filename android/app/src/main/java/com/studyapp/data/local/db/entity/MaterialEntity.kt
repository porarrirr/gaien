package com.studyapp.data.local.db.entity

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation

@Entity(
    tableName = "materials",
    foreignKeys = [
        ForeignKey(
            entity = SubjectEntity::class,
            parentColumns = ["id"],
            childColumns = ["subjectId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("subjectId")]
)
data class MaterialEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val syncId: String = "",
    val name: String,
    val subjectId: Long,
    val subjectSyncId: String? = null,
    val sortOrder: Long = System.currentTimeMillis(),
    val totalPages: Int = 0,
    val currentPage: Int = 0,
    val color: Int? = null,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val progress: Float
        get() = if (totalPages > 0) currentPage.toFloat() / totalPages.toFloat() else 0f
}

data class MaterialWithSubject(
    @Embedded val material: MaterialEntity,
    @Relation(
        parentColumn = "subjectId",
        entityColumn = "id"
    )
    val subject: SubjectEntity?
)
