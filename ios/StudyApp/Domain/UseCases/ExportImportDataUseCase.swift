import Foundation

struct ExportImportDataUseCase {
    let repository: AppDataRepository

    func exportJSON() async throws -> String {
        try await repository.exportJSON()
    }

    func exportCSV() async throws -> String {
        try await repository.exportCSV()
    }

    func importJSON(_ json: String, currentPreferences: AppPreferences) async throws -> AppPreferences {
        try await repository.importJSON(json, currentPreferences: currentPreferences)
    }
}

struct GetSettingsSummaryUseCase {
    let sessionRepository: StudySessionRepository

    func execute() async throws -> SettingsSummary {
        let sessions = try await sessionRepository.getAllSessions()
        return SettingsSummary(
            totalSessions: sessions.count,
            totalStudyMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }
        )
    }
}
