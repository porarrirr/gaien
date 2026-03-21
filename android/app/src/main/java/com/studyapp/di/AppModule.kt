package com.studyapp.di

import android.content.Context
import android.util.Log
import androidx.room.Room
import com.studyapp.BuildConfig
import com.studyapp.data.local.db.ALL_MIGRATIONS
import com.studyapp.data.local.db.StudyDatabase
import com.studyapp.data.local.db.dao.*
import com.studyapp.data.repository.*
import com.studyapp.data.service.GoogleBooksService
import com.studyapp.data.service.TimerServiceManagerImpl
import com.studyapp.data.service.TimerStateStore
import com.studyapp.domain.repository.*
import com.studyapp.domain.usecase.*
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.SystemClock
import com.studyapp.sync.AuthRepository
import com.studyapp.sync.FirebaseAuthRepository
import com.studyapp.sync.FirebaseSyncRepository
import com.studyapp.sync.SyncRepository
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    
    @Provides
    @Singleton
    fun provideClock(): Clock = SystemClock()
    
    @Provides
    @Singleton
    fun provideTimerStateStore(@ApplicationContext context: Context): TimerStateStore {
        return TimerStateStore(context)
    }

    @Provides
    @Singleton
    fun provideFirebaseAuth(): FirebaseAuth = FirebaseAuth.getInstance()

    @Provides
    @Singleton
    fun provideFirebaseFirestore(): FirebaseFirestore = FirebaseFirestore.getInstance()
}

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): StudyDatabase {
        return Room.databaseBuilder(
            context,
            StudyDatabase::class.java,
            "study_app.db"
        )
            .addMigrations(*ALL_MIGRATIONS)
            .build()
    }
    
    @Provides
    fun provideSubjectDao(database: StudyDatabase): SubjectDao {
        return database.subjectDao()
    }
    
    @Provides
    fun provideMaterialDao(database: StudyDatabase): MaterialDao {
        return database.materialDao()
    }
    
    @Provides
    fun provideStudySessionDao(database: StudyDatabase): StudySessionDao {
        return database.studySessionDao()
    }
    
    @Provides
    fun provideGoalDao(database: StudyDatabase): GoalDao {
        return database.goalDao()
    }
    
    @Provides
    fun provideExamDao(database: StudyDatabase): ExamDao {
        return database.examDao()
    }
    
    @Provides
    fun providePlanDao(database: StudyDatabase): PlanDao {
        return database.planDao()
    }
}

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder().apply {
            if (BuildConfig.DEBUG) {
                addInterceptor(
                    Interceptor { chain ->
                        val request = chain.request()
                        Log.d(
                            "GoogleBooksNetwork",
                            "${request.method} ${request.url.newBuilder().query(null).build()}"
                        )
                        chain.proceed(request)
                    }
                )
            }
        }
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .writeTimeout(15, TimeUnit.SECONDS)
            .build()
    }
    
    @Provides
    @Singleton
    fun provideGoogleBooksService(okHttpClient: OkHttpClient): GoogleBooksService {
        return GoogleBooksService(okHttpClient)
    }
}

@Module
@InstallIn(SingletonComponent::class)
interface RepositoryModule {
    
    @Binds
    @Singleton
    fun bindSubjectRepository(impl: SubjectRepositoryImpl): SubjectRepository
    
    @Binds
    @Singleton
    fun bindMaterialRepository(impl: MaterialRepositoryImpl): MaterialRepository
    
    @Binds
    @Singleton
    fun bindStudySessionRepository(impl: StudySessionRepositoryImpl): StudySessionRepository
    
    @Binds
    @Singleton
    fun bindGoalRepository(impl: GoalRepositoryImpl): GoalRepository
    
    @Binds
    @Singleton
    fun bindExamRepository(impl: ExamRepositoryImpl): ExamRepository
    
    @Binds
    @Singleton
    fun bindPlanRepository(impl: PlanRepositoryImpl): PlanRepository
    
    @Binds
    @Singleton
    fun bindTimerServiceManager(impl: TimerServiceManagerImpl): TimerServiceManager

    @Binds
    @Singleton
    fun bindAuthRepository(impl: FirebaseAuthRepository): AuthRepository

    @Binds
    @Singleton
    fun bindSyncRepository(impl: FirebaseSyncRepository): SyncRepository
}

@Module
@InstallIn(SingletonComponent::class)
object UseCaseModule {
    
    @Provides
    @Singleton
    fun provideGetHomeDataUseCase(
        studySessionRepository: StudySessionRepository,
        goalRepository: GoalRepository,
        examRepository: ExamRepository,
        clock: Clock
    ): GetHomeDataUseCase {
        return GetHomeDataUseCase(studySessionRepository, goalRepository, examRepository, clock)
    }
    
    @Provides
    @Singleton
    fun provideManageMaterialsUseCase(
        materialRepository: MaterialRepository,
        clock: Clock
    ): ManageMaterialsUseCase {
        return ManageMaterialsUseCase(materialRepository, clock)
    }
    
    @Provides
    @Singleton
    fun provideManageGoalsUseCase(
        goalRepository: GoalRepository
    ): ManageGoalsUseCase {
        return ManageGoalsUseCase(goalRepository)
    }
    
    @Provides
    @Singleton
    fun provideGetUpcomingExamsUseCase(
        examRepository: ExamRepository,
        clock: Clock
    ): GetUpcomingExamsUseCase {
        return GetUpcomingExamsUseCase(examRepository, clock)
    }
    
    @Provides
    @Singleton
    fun provideSaveStudySessionUseCase(
        studySessionRepository: StudySessionRepository,
        subjectRepository: SubjectRepository,
        materialRepository: MaterialRepository,
        clock: Clock
    ): SaveStudySessionUseCase {
        return SaveStudySessionUseCase(studySessionRepository, subjectRepository, materialRepository, clock)
    }
    
    @Provides
    @Singleton
    fun provideGetReportsDataUseCase(
        studySessionRepository: StudySessionRepository,
        clock: Clock
    ): GetReportsDataUseCase {
        return GetReportsDataUseCase(studySessionRepository, clock)
    }
    
    @Provides
    @Singleton
    fun provideManagePlansUseCase(
        planRepository: PlanRepository
    ): ManagePlansUseCase {
        return ManagePlansUseCase(planRepository)
    }
    
    @Provides
    @Singleton
    fun provideGetRecentMaterialsUseCase(
        studySessionRepository: StudySessionRepository,
        materialRepository: MaterialRepository,
        subjectRepository: SubjectRepository
    ): GetRecentMaterialsUseCase {
        return GetRecentMaterialsUseCase(studySessionRepository, materialRepository, subjectRepository)
    }
    
    @Provides
    @Singleton
    fun provideExportImportDataUseCase(
        subjectRepository: SubjectRepository,
        materialRepository: MaterialRepository,
        studySessionRepository: StudySessionRepository,
        goalRepository: GoalRepository,
        examRepository: ExamRepository,
        planRepository: PlanRepository,
        database: StudyDatabase,
        writeLock: com.studyapp.sync.AppDataWriteLock
    ): ExportImportDataUseCase {
        return ExportImportDataUseCase(
            subjectRepository,
            materialRepository,
            studySessionRepository,
            goalRepository,
            examRepository,
            planRepository,
            database,
            writeLock
        )
    }
}
