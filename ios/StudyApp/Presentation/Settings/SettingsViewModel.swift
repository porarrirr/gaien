import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SettingsViewModel: ScreenViewModel {
    @Published private(set) var exportURL: URL?
    @Published private(set) var summary = SettingsSummary(totalSessions: 0, totalStudyMinutes: 0)
    @Published private(set) var debugLogEntries: [DebugLogEntry] = []
    @Published var syncEmail = ""
    @Published var syncPassword = ""

    func load() async {
        do {
            let useCase = GetSettingsSummaryUseCase(sessionRepository: app.persistence)
            summary = try await useCase.execute()
            app.refreshSyncStatus()
            debugLogEntries = app.logger.recentEntries()
        } catch {
            app.present(error)
        }
    }

    func export(format: ExportFormat) {
        perform {
            let useCase = ExportImportDataUseCase(repository: self.app.persistence)
            let contents = try await (format == .json ? useCase.exportJSON() : useCase.exportCSV())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("studyapp_backup_\(Int(Date().timeIntervalSince1970)).\(format.rawValue)")
            try contents.write(to: url, atomically: true, encoding: .utf8)
            self.app.logger.log(category: .app, message: "Export completed", details: "format=\(format.rawValue) url=\(url.lastPathComponent)")
            self.exportURL = url
        }
    }

    func importBackup(from url: URL) {
        perform {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let useCase = ExportImportDataUseCase(repository: self.app.persistence)
            let preferences = try await useCase.importJSON(contents, currentPreferences: self.app.preferences)
            self.app.savePreferences { $0 = preferences }
            self.app.logger.log(category: .app, message: "Backup import completed", details: "file=\(url.lastPathComponent)")
            self.app.bumpDataVersion()
        }
    }

    func deleteAllData() {
        perform {
            try await self.app.persistence.deleteAllData()
            if self.app.syncStatus.isAuthenticated {
                try await self.app.syncRepository.importLocalDataToCloud()
            } else {
                await self.app.syncRepository.clearLocalSyncState()
            }
            self.app.updateActiveTimer(nil)
            self.summary = SettingsSummary(totalSessions: 0, totalStudyMinutes: 0)
            self.app.logger.log(category: .app, level: .warning, message: "All local data deleted")
            self.app.bumpDataVersion(shouldScheduleAutoSync: false)
            self.app.recordManualSyncApplied()
        }
    }

    func signInToSync() {
        perform {
            let password = self.syncPassword
            let email = self.syncEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            defer { self.syncPassword = "" }
            self.app.logger.log(category: .auth, message: "Sign in requested", details: "emailProvided=\(!email.isEmpty) passwordLength=\(password.count)")
            try await self.app.authRepository.signIn(email: email, password: password)
            self.app.refreshSyncStatus()
            self.app.scheduleAutoSync(reason: "sign-in")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func createSyncAccount() {
        perform {
            let password = self.syncPassword
            let email = self.syncEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            defer { self.syncPassword = "" }
            self.app.logger.log(category: .auth, message: "Sign up requested", details: "emailProvided=\(!email.isEmpty) passwordLength=\(password.count)")
            try await self.app.authRepository.signUp(email: email, password: password)
            self.app.refreshSyncStatus()
            self.app.scheduleAutoSync(reason: "sign-up")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func signOutOfSync() {
        perform {
            try await self.app.authRepository.signOut()
            self.app.logger.log(category: .auth, message: "Sign out completed")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func syncNow() {
        guard !app.syncStatus.isSyncing else {
            app.logger.log(category: .sync, level: .warning, message: "syncNow ignored in view model", details: "reason=already-syncing")
            return
        }
        perform {
            try await self.app.syncRepository.syncNow()
            self.app.refreshSyncStatus()
            self.summary = try await GetSettingsSummaryUseCase(sessionRepository: self.app.persistence).execute()
            self.debugLogEntries = self.app.logger.recentEntries()
            self.app.bumpDataVersion(shouldScheduleAutoSync: false)
            self.app.recordManualSyncApplied()
        }
    }

    func importLocalDataToCloud() {
        guard !app.syncStatus.isSyncing else {
            app.logger.log(category: .sync, level: .warning, message: "importLocalDataToCloud ignored in view model", details: "reason=already-syncing")
            return
        }
        perform {
            try await self.app.syncRepository.importLocalDataToCloud()
            self.app.refreshSyncStatus()
            self.app.recordManualSyncApplied()
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func refreshDebugLogs() {
        debugLogEntries = app.logger.recentEntries()
    }

    func exportDebugLogs() {
        guard AppLogger.isDebugToolsEnabled else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("studyapp_debug_logs_\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try app.logger.exportText().write(to: url, atomically: true, encoding: .utf8)
            app.logger.log(category: .app, message: "Debug logs exported", details: "file=\(url.lastPathComponent)")
            exportURL = url
            debugLogEntries = app.logger.recentEntries()
        } catch {
            app.present(error)
        }
    }

    func copyDebugLogs() {
        guard AppLogger.isDebugToolsEnabled else { return }
        #if canImport(UIKit)
        UIPasteboard.general.string = app.logger.exportText()
        app.logger.log(category: .app, message: "Debug logs copied to clipboard", details: "entryCount=\(app.logger.recentEntries().count)")
        debugLogEntries = app.logger.recentEntries()
        #endif
    }

    func clearDebugLogs() {
        app.logger.clear()
        app.logger.log(category: .app, level: .warning, message: "Debug logs cleared")
        debugLogEntries = app.logger.recentEntries()
    }
}
