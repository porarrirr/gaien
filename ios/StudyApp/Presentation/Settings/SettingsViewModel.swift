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
    @Published private(set) var dataBackups: [DataBackupDescriptor] = []
    @Published var syncEmail = ""
    @Published var syncPassword = ""
    @Published var accountDeletionPassword = ""

    func load() async {
        do {
            let useCase = GetSettingsSummaryUseCase(sessionRepository: app.sessionRepo)
            summary = try await useCase.execute()
            app.refreshSyncStatus()
            debugLogEntries = app.logger.recentEntries()
            dataBackups = try await app.appDataRepo.listDataBackups()
        } catch {
            app.present(error)
        }
    }

    func export(format: ExportFormat) {
        perform {
            let useCase = ExportImportDataUseCase(repository: self.app.appDataRepo)
            let contents = try await (format == .json ? useCase.exportJSON() : useCase.exportCSV())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("studyapp_backup_\(Int(Date().timeIntervalSince1970)).\(format.rawValue)")
            try contents.write(to: url, atomically: true, encoding: .utf8)
            self.app.logger.log(category: .app, message: "Export completed", details: "format=\(format.rawValue) url=\(url.lastPathComponent)")
            self.exportURL = url
        }
    }

    func importBackup(from url: URL) {
        perform {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try await self.restoreBackup(at: url, source: "manual-import")
        }
    }

    func restoreDataBackup(_ backup: DataBackupDescriptor) {
        perform {
            try await self.restoreBackup(at: backup.url, source: "automatic-backup")
        }
    }

    func deleteAllData() {
        perform {
            if self.app.syncStatus.isAuthenticated {
                try await self.app.syncRepository.deleteCloudDataForCurrentUser()
            } else {
                await self.app.syncRepository.clearLocalSyncState()
            }
            try await self.app.appDataRepo.deleteAllData()
            await self.app.syncRepository.clearLocalSyncState()
            self.app.updateActiveTimer(nil)
            self.summary = SettingsSummary(totalSessions: 0, totalStudyMinutes: 0)
            self.app.logger.log(category: .app, level: .warning, message: "All local data deleted")
            self.app.bumpDataVersion(shouldScheduleAutoSync: false)
            self.app.recordManualSyncApplied()
        }
    }

    func signInToSync() {
        signInToSync(email: syncEmail, password: syncPassword) {
            self.syncPassword = ""
        }
    }

    func signInToSync(email rawEmail: String, password rawPassword: String) {
        signInToSync(email: rawEmail, password: rawPassword, clearPassword: {})
    }

    private func signInToSync(email rawEmail: String, password rawPassword: String, clearPassword: @escaping () -> Void) {
        perform {
            let password = self.normalizedAuthPassword(rawPassword)
            let email = self.normalizedAuthEmail(rawEmail)
            defer { clearPassword() }
            self.app.logger.log(
                category: .auth,
                message: "Sign in requested",
                details: "emailProvided=\(!email.isEmpty) emailNormalized=\(email != rawEmail) passwordLength=\(password.count)"
            )
            try await self.app.authRepository.signIn(email: email, password: password)
            self.app.refreshSyncStatus()
            self.app.scheduleAutoSync(reason: "sign-in")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func createSyncAccount() {
        createSyncAccount(email: syncEmail, password: syncPassword) {
            self.syncPassword = ""
        }
    }

    func createSyncAccount(email rawEmail: String, password rawPassword: String) {
        createSyncAccount(email: rawEmail, password: rawPassword, clearPassword: {})
    }

    private func createSyncAccount(email rawEmail: String, password rawPassword: String, clearPassword: @escaping () -> Void) {
        perform {
            let password = self.normalizedAuthPassword(rawPassword)
            let email = self.normalizedAuthEmail(rawEmail)
            defer { clearPassword() }
            self.app.logger.log(
                category: .auth,
                message: "Sign up requested",
                details: "emailProvided=\(!email.isEmpty) emailNormalized=\(email != rawEmail) passwordLength=\(password.count)"
            )
            try await self.app.authRepository.signUp(email: email, password: password)
            self.app.refreshSyncStatus()
            self.app.scheduleAutoSync(reason: "sign-up")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func sendPasswordReset() {
        sendPasswordReset(email: syncEmail)
    }

    func sendPasswordReset(email rawEmail: String) {
        perform {
            let email = self.normalizedAuthEmail(rawEmail)
            guard !email.isEmpty else {
                throw ValidationError(message: "メールアドレスを入力してください")
            }
            try await self.app.authRepository.sendPasswordReset(email: email)
            self.app.present("パスワード再設定メールを送信しました")
            self.app.logger.log(category: .auth, message: "Password reset requested")
        }
    }

    func deleteSyncAccount() {
        perform {
            let password = self.removingAuthInputNoise(from: self.accountDeletionPassword)
            defer { self.accountDeletionPassword = "" }
            guard !password.isEmpty else {
                throw ValidationError(message: "アカウント削除には現在のパスワードが必要です")
            }

            try await self.app.authRepository.reauthenticate(password: password)
            let backupURL = try await self.writeDeletionBackup(reason: "before-account-delete")
            try await self.app.syncRepository.deleteCloudDataForCurrentUser()
            try await self.app.authRepository.deleteAccount(password: password)
            try await self.app.appDataRepo.deleteAllData()
            await self.app.syncRepository.clearLocalSyncState()
            self.app.refreshSyncStatus()
            self.summary = SettingsSummary(totalSessions: 0, totalStudyMinutes: 0)
            self.app.updateActiveTimer(nil)
            self.app.bumpDataVersion(shouldScheduleAutoSync: false)
            self.app.recordManualSyncApplied()
            self.app.logger.log(category: .auth, level: .warning, message: "Sync account and associated data deleted", details: "backup=\(backupURL.lastPathComponent)")
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
            self.summary = try await GetSettingsSummaryUseCase(sessionRepository: self.app.sessionRepo).execute()
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

    func resolveSyncConflicts(_ resolutions: [SyncConflictResolution]) {
        guard !app.syncStatus.isSyncing else { return }
        perform {
            try await self.app.syncRepository.resolveConflicts(resolutions)
            self.app.refreshSyncStatus()
            self.summary = try await GetSettingsSummaryUseCase(sessionRepository: self.app.sessionRepo).execute()
            self.debugLogEntries = self.app.logger.recentEntries()
            self.app.bumpDataVersion(shouldScheduleAutoSync: false)
            self.app.recordManualSyncApplied()
        }
    }

    func refreshDebugLogs() {
        debugLogEntries = app.logger.recentEntries()
    }

    func exportDebugLogs() {
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

    private func writeDeletionBackup(reason: String) async throws -> URL {
        let persistentBackup = try await app.appDataRepo.createDataBackup(reason: reason)
        let contents = try await ExportImportDataUseCase(repository: app.appDataRepo).exportJSON()
        let formatter = StudyFormatters.fileSafeTimestamp
        let fileName = "studyapp_backup_\(reason)_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        app.logger.log(
            category: .app,
            level: .warning,
            message: "Deletion backup created",
            details: "shareFile=\(url.lastPathComponent) persistentFile=\(persistentBackup.fileName)"
        )
        return url
    }

    private func restoreBackup(at url: URL, source: String) async throws {
        _ = try await app.appDataRepo.createDataBackup(reason: "before-restore")
        let contents = try String(contentsOf: url, encoding: .utf8)
        let useCase = ExportImportDataUseCase(repository: app.appDataRepo)
        let preferences = try await useCase.importJSON(contents, currentPreferences: app.preferences)
        app.savePreferences { $0 = preferences }
        dataBackups = try await app.appDataRepo.listDataBackups()
        app.logger.log(
            category: .app,
            message: "Backup restore completed",
            details: "source=\(source) file=\(url.lastPathComponent)"
        )
        app.bumpDataVersion()
    }

    private func normalizedAuthEmail(_ value: String) -> String {
        let halfWidthEmail = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
        return removingAuthInputNoise(from: halfWidthEmail).lowercased()
    }

    private func normalizedAuthPassword(_ value: String) -> String {
        let halfWidthPassword = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
        return removingAuthInputNoise(from: halfWidthPassword)
    }

    private func removingAuthInputNoise(from value: String) -> String {
        let invisibleScalars = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        let disallowedScalars = CharacterSet.whitespacesAndNewlines.union(invisibleScalars)
        var normalizedScalars = String.UnicodeScalarView()
        for scalar in value.unicodeScalars where !disallowedScalars.contains(scalar) {
            normalizedScalars.append(scalar)
        }
        return String(normalizedScalars)
    }
}
