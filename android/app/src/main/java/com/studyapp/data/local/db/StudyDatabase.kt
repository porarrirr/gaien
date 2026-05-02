package com.studyapp.data.local.db

import androidx.room.Database
import androidx.room.RoomDatabase
import com.studyapp.data.local.db.dao.*
import com.studyapp.data.local.db.entity.*

@Database(
    entities = [
        SubjectEntity::class,
        MaterialEntity::class,
        StudySessionEntity::class,
        GoalEntity::class,
        ExamEntity::class,
        PlanEntity::class,
        PlanItemEntity::class,
        TimetablePeriodEntity::class,
        TimetableTermEntity::class,
        TimetableEntryEntity::class,
        TimetableReviewRecordEntity::class
    ],
    version = 11,
    exportSchema = true
)
abstract class StudyDatabase : RoomDatabase() {
    abstract fun subjectDao(): SubjectDao
    abstract fun materialDao(): MaterialDao
    abstract fun studySessionDao(): StudySessionDao
    abstract fun goalDao(): GoalDao
    abstract fun examDao(): ExamDao
    abstract fun planDao(): PlanDao
    abstract fun timetablePeriodDao(): TimetablePeriodDao
    abstract fun timetableTermDao(): TimetableTermDao
    abstract fun timetableEntryDao(): TimetableEntryDao
    abstract fun timetableReviewRecordDao(): TimetableReviewRecordDao
}
