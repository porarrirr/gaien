package com.studyapp.data.local.db

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS study_plans (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                name TEXT NOT NULL,
                startDate INTEGER NOT NULL,
                endDate INTEGER NOT NULL,
                isActive INTEGER NOT NULL,
                createdAt INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS plan_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                planId INTEGER NOT NULL,
                subjectId INTEGER NOT NULL,
                dayOfWeek INTEGER NOT NULL,
                targetMinutes INTEGER NOT NULL,
                actualMinutes INTEGER NOT NULL,
                timeSlot TEXT,
                FOREIGN KEY (planId) REFERENCES study_plans(id) ON DELETE CASCADE,
                FOREIGN KEY (subjectId) REFERENCES subjects(id) ON DELETE CASCADE
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS index_plan_items_planId ON plan_items(planId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_plan_items_subjectId ON plan_items(subjectId)")
    }
}

val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("CREATE INDEX IF NOT EXISTS index_exams_date ON exams(date)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_goals_type ON goals(type)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_goals_isActive ON goals(isActive)")
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_goals_type_isActive ON goals(type, isActive)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_study_sessions_startTime ON study_sessions(startTime)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_study_plans_isActive ON study_plans(isActive)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_study_plans_createdAt ON study_plans(createdAt)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_plan_items_planId_dayOfWeek ON plan_items(planId, dayOfWeek)")
    }
}

val ALL_MIGRATIONS = arrayOf(MIGRATION_1_2, MIGRATION_2_3)
