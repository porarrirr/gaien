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

val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        listOf(
            "subjects",
            "materials",
            "study_sessions",
            "goals",
            "exams",
            "study_plans",
            "plan_items"
        ).forEach { table ->
            db.execSQL("ALTER TABLE $table ADD COLUMN syncId TEXT NOT NULL DEFAULT ''")
            db.execSQL("ALTER TABLE $table ADD COLUMN deletedAt INTEGER")
            db.execSQL("ALTER TABLE $table ADD COLUMN lastSyncedAt INTEGER")
        }

        db.execSQL("ALTER TABLE materials ADD COLUMN subjectSyncId TEXT")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN materialSyncId TEXT")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN subjectSyncId TEXT")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE study_plans ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE plan_items ADD COLUMN planSyncId TEXT")
        db.execSQL("ALTER TABLE plan_items ADD COLUMN subjectSyncId TEXT")
        db.execSQL("ALTER TABLE plan_items ADD COLUMN createdAt INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE plan_items ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0")

        val now = System.currentTimeMillis()
        db.execSQL("UPDATE subjects SET syncId = 'subject-' || id, lastSyncedAt = NULL WHERE syncId = ''")
        db.execSQL("UPDATE materials SET syncId = 'material-' || id, subjectSyncId = 'subject-' || subjectId WHERE syncId = ''")
        db.execSQL("UPDATE study_sessions SET syncId = 'session-' || id, materialSyncId = CASE WHEN materialId IS NULL THEN NULL ELSE 'material-' || materialId END, subjectSyncId = 'subject-' || subjectId, updatedAt = createdAt WHERE syncId = ''")
        db.execSQL("UPDATE goals SET syncId = 'goal-' || id WHERE syncId = ''")
        db.execSQL("UPDATE exams SET syncId = 'exam-' || id WHERE syncId = ''")
        db.execSQL("UPDATE study_plans SET syncId = 'plan-' || id, updatedAt = createdAt WHERE syncId = ''")
        db.execSQL("UPDATE plan_items SET syncId = 'plan-item-' || id, planSyncId = 'plan-' || planId, subjectSyncId = 'subject-' || subjectId, createdAt = $now, updatedAt = $now WHERE syncId = ''")

        db.execSQL("CREATE INDEX IF NOT EXISTS index_subjects_syncId ON subjects(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_materials_syncId ON materials(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_study_sessions_syncId ON study_sessions(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_goals_syncId ON goals(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_exams_syncId ON exams(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_study_plans_syncId ON study_plans(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_plan_items_syncId ON plan_items(syncId)")
    }
}

val ALL_MIGRATIONS = arrayOf(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4)
