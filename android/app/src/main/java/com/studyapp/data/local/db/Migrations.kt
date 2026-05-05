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

        db.execSQL("UPDATE subjects SET syncId = printf('subject-%s', lower(hex(randomblob(16)))), lastSyncedAt = NULL WHERE syncId = ''")
        db.execSQL("UPDATE materials SET syncId = printf('material-%s', lower(hex(randomblob(16)))) WHERE syncId = ''")
        db.execSQL("UPDATE materials SET subjectSyncId = (SELECT syncId FROM subjects WHERE subjects.id = materials.subjectId) WHERE subjectSyncId IS NULL")
        db.execSQL("UPDATE study_sessions SET syncId = printf('session-%s', lower(hex(randomblob(16)))) WHERE syncId = ''")
        db.execSQL(
            """
            UPDATE study_sessions
            SET materialSyncId = CASE
                    WHEN materialId IS NULL THEN NULL
                    ELSE (SELECT syncId FROM materials WHERE materials.id = study_sessions.materialId)
                END,
                subjectSyncId = (SELECT syncId FROM subjects WHERE subjects.id = study_sessions.subjectId),
                updatedAt = CASE WHEN updatedAt = 0 THEN createdAt ELSE updatedAt END
            WHERE materialSyncId IS NULL OR subjectSyncId IS NULL OR updatedAt = 0
            """.trimIndent()
        )
        db.execSQL("UPDATE goals SET syncId = printf('goal-%s', lower(hex(randomblob(16)))) WHERE syncId = ''")
        db.execSQL("UPDATE exams SET syncId = printf('exam-%s', lower(hex(randomblob(16)))) WHERE syncId = ''")
        db.execSQL("UPDATE study_plans SET syncId = printf('plan-%s', lower(hex(randomblob(16)))) WHERE syncId = ''")
        db.execSQL("UPDATE study_plans SET updatedAt = CASE WHEN updatedAt = 0 THEN createdAt ELSE updatedAt END WHERE updatedAt = 0")
        db.execSQL("UPDATE plan_items SET syncId = printf('plan-item-%s', lower(hex(randomblob(16)))) WHERE syncId = ''")
        db.execSQL(
            """
            UPDATE plan_items
            SET planSyncId = (SELECT syncId FROM study_plans WHERE study_plans.id = plan_items.planId),
                subjectSyncId = (SELECT syncId FROM subjects WHERE subjects.id = plan_items.subjectId),
                createdAt = CASE
                    WHEN createdAt = 0 THEN COALESCE(
                        (SELECT createdAt FROM study_plans WHERE study_plans.id = plan_items.planId),
                        CAST(strftime('%s','now') AS INTEGER) * 1000 + id
                    )
                    ELSE createdAt
                END,
                updatedAt = CASE
                    WHEN updatedAt = 0 THEN COALESCE(
                        (SELECT updatedAt FROM study_plans WHERE study_plans.id = plan_items.planId),
                        (SELECT createdAt FROM study_plans WHERE study_plans.id = plan_items.planId),
                        CAST(strftime('%s','now') AS INTEGER) * 1000 + id
                    )
                    ELSE updatedAt
                END
            WHERE planSyncId IS NULL OR subjectSyncId IS NULL OR createdAt = 0 OR updatedAt = 0
            """.trimIndent()
        )

        db.execSQL("CREATE INDEX IF NOT EXISTS index_subjects_syncId ON subjects(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_materials_syncId ON materials(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_study_sessions_syncId ON study_sessions(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_goals_syncId ON goals(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_exams_syncId ON exams(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_study_plans_syncId ON study_plans(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_plan_items_syncId ON plan_items(syncId)")
    }
}

val MIGRATION_4_5 = object : Migration(4, 5) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS goals_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                syncId TEXT NOT NULL,
                type TEXT NOT NULL,
                targetMinutes INTEGER NOT NULL,
                dayOfWeek INTEGER NOT NULL DEFAULT 0,
                weekStartDay INTEGER NOT NULL,
                isActive INTEGER NOT NULL,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                deletedAt INTEGER,
                lastSyncedAt INTEGER
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            INSERT INTO goals_new (
                syncId,
                type,
                targetMinutes,
                dayOfWeek,
                weekStartDay,
                isActive,
                createdAt,
                updatedAt,
                deletedAt,
                lastSyncedAt
            )
            SELECT
                syncId,
                type,
                targetMinutes,
                0,
                weekStartDay,
                isActive,
                createdAt,
                updatedAt,
                deletedAt,
                lastSyncedAt
            FROM goals
            WHERE type != 'DAILY'
            """.trimIndent()
        )

        for (day in 1..7) {
            db.execSQL(
                """
                INSERT INTO goals_new (
                    syncId,
                    type,
                    targetMinutes,
                    dayOfWeek,
                    weekStartDay,
                    isActive,
                    createdAt,
                    updatedAt,
                    deletedAt,
                    lastSyncedAt
                )
                SELECT
                    syncId || '-$day',
                    type,
                    targetMinutes,
                    $day,
                    weekStartDay,
                    isActive,
                    createdAt,
                    updatedAt,
                    deletedAt,
                    lastSyncedAt
                FROM goals
                WHERE type = 'DAILY'
                """.trimIndent()
            )
        }

        db.execSQL("DROP TABLE goals")
        db.execSQL("ALTER TABLE goals_new RENAME TO goals")
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_goals_type_dayOfWeek_isActive ON goals(type, dayOfWeek, isActive)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_goals_syncId ON goals(syncId)")
    }
}

val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN intervalsJson TEXT")
    }
}

val MIGRATION_6_7 = object : Migration(6, 7) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE materials ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN sessionType TEXT NOT NULL DEFAULT 'STOPWATCH'")
        db.execSQL("UPDATE materials SET sortOrder = CASE WHEN sortOrder = 0 THEN id ELSE sortOrder END")
    }
}

val MIGRATION_7_8 = object : Migration(7, 8) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN rating INTEGER")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN problemStart INTEGER")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN problemEnd INTEGER")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN wrongProblemCount INTEGER")
        db.execSQL("ALTER TABLE study_sessions ADD COLUMN problemRecordsJson TEXT")
    }
}

val MIGRATION_8_9 = object : Migration(8, 9) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE materials ADD COLUMN totalProblems INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE materials ADD COLUMN problemChaptersJson TEXT")
        db.execSQL("ALTER TABLE materials ADD COLUMN problemRecordsJson TEXT")
    }
}

val MIGRATION_9_10 = object : Migration(9, 10) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS timetable_periods (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                syncId TEXT NOT NULL DEFAULT '',
                name TEXT NOT NULL,
                startMinute INTEGER NOT NULL,
                endMinute INTEGER NOT NULL,
                sortOrder INTEGER NOT NULL,
                isActive INTEGER NOT NULL DEFAULT 1,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                deletedAt INTEGER,
                lastSyncedAt INTEGER
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS timetable_terms (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                syncId TEXT NOT NULL DEFAULT '',
                name TEXT NOT NULL,
                startDate INTEGER NOT NULL,
                endDate INTEGER NOT NULL,
                isActive INTEGER NOT NULL DEFAULT 1,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                deletedAt INTEGER,
                lastSyncedAt INTEGER
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS timetable_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                syncId TEXT NOT NULL DEFAULT '',
                termId INTEGER,
                termSyncId TEXT,
                dayOfWeek INTEGER NOT NULL,
                periodId INTEGER NOT NULL,
                periodSyncId TEXT,
                subjectName TEXT NOT NULL,
                courseName TEXT,
                roomName TEXT,
                validFromDate INTEGER,
                validToDate INTEGER,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                deletedAt INTEGER,
                lastSyncedAt INTEGER,
                FOREIGN KEY (periodId) REFERENCES timetable_periods(id) ON DELETE CASCADE
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS timetable_review_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                syncId TEXT NOT NULL DEFAULT '',
                termId INTEGER NOT NULL,
                termSyncId TEXT,
                entryId INTEGER NOT NULL,
                entrySyncId TEXT,
                periodId INTEGER NOT NULL,
                periodSyncId TEXT,
                occurrenceDate INTEGER NOT NULL,
                dayOfWeek INTEGER NOT NULL,
                periodName TEXT NOT NULL,
                periodStartMinute INTEGER NOT NULL,
                periodEndMinute INTEGER NOT NULL,
                subjectName TEXT NOT NULL,
                courseName TEXT,
                roomName TEXT,
                isReviewed INTEGER NOT NULL DEFAULT 0,
                note TEXT,
                isExcluded INTEGER NOT NULL DEFAULT 0,
                reviewedAt INTEGER,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                deletedAt INTEGER,
                lastSyncedAt INTEGER
            )
            """.trimIndent()
        )
    }
}

val MIGRATION_10_11 = object : Migration(10, 11) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_periods_syncId ON timetable_periods(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_periods_isActive ON timetable_periods(isActive)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_terms_syncId ON timetable_terms(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_terms_isActive ON timetable_terms(isActive)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_entries_syncId ON timetable_entries(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_entries_periodId ON timetable_entries(periodId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_entries_termId ON timetable_entries(termId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_entries_dayOfWeek ON timetable_entries(dayOfWeek)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_review_records_syncId ON timetable_review_records(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_review_records_termId ON timetable_review_records(termId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_review_records_entryId ON timetable_review_records(entryId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_review_records_occurrenceDate ON timetable_review_records(occurrenceDate)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_timetable_review_records_periodId ON timetable_review_records(periodId)")
    }
}

val MIGRATION_11_12 = object : Migration(11, 12) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS problem_review_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                syncId TEXT NOT NULL,
                problemId TEXT NOT NULL,
                materialId INTEGER NOT NULL,
                materialSyncId TEXT,
                problemNumber INTEGER NOT NULL,
                reviewedAt INTEGER NOT NULL,
                rating TEXT NOT NULL,
                nextReviewDate INTEGER NOT NULL,
                consecutiveCorrectCount INTEGER NOT NULL DEFAULT 0,
                wrongCount INTEGER NOT NULL DEFAULT 0,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                deletedAt INTEGER,
                lastSyncedAt INTEGER
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS index_problem_review_records_syncId ON problem_review_records(syncId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_problem_review_records_problemId ON problem_review_records(problemId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_problem_review_records_materialId ON problem_review_records(materialId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_problem_review_records_nextReviewDate ON problem_review_records(nextReviewDate)")
    }
}

val ALL_MIGRATIONS = arrayOf(
    MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5,
    MIGRATION_5_6, MIGRATION_6_7, MIGRATION_7_8, MIGRATION_8_9,
    MIGRATION_9_10, MIGRATION_10_11, MIGRATION_11_12
)
