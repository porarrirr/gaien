import Combine
import Foundation

@MainActor
final class TimerViewModel: ScreenViewModel {
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var materials: [Material] = []
    @Published private(set) var elapsedMilliseconds: Int64 = 0
    @Published private(set) var remainingMilliseconds: Int64 = 0
    @Published var pendingSessionEvaluation: PendingSessionEvaluation?
    @Published var selectedSubjectId: Int64?
    @Published var selectedMaterialId: Int64?
    @Published var mode: TimerSnapshot.Mode = .stopwatch
    @Published var countdownMinutes: Int = 25
    @Published private(set) var timerProblemRecords: [ProblemSessionRecord] = []
    @Published private(set) var timerProblemCountDraft = ""

    private var cancellable: AnyCancellable?
    private var lastScreenTimeGoalSyncMinute: Int64?

    func load() async {
        do {
            async let subjectsTask = app.subjectRepo.getAllSubjects()
            async let materialsTask = app.materialRepo.getAllMaterials()
            subjects = try await subjectsTask
            materials = try await materialsTask
            let activeTimer = app.preferences.activeTimer
            selectedSubjectId = resolveSelectedSubjectId(activeTimer: activeTimer)
            selectedMaterialId = resolveSelectedMaterialId(activeTimer: activeTimer, subjectId: selectedSubjectId)
            elapsedMilliseconds = activeTimer?.elapsedTime() ?? 0
            remainingMilliseconds = activeTimer?.remainingTime() ?? 0
            mode = activeTimer?.mode ?? .stopwatch
            countdownMinutes = Int(((activeTimer?.targetDurationMilliseconds ?? Int64(countdownMinutes) * 60_000) / 60_000))
            timerProblemRecords = ProblemSessionReviewResolver.canonicalInputRecords(activeTimer?.problemRecords ?? [])
            timerProblemCountDraft = activeTimer?.problemCountDraft ?? ""
            syncActiveTimerSelection()
            configureTicker()
        } catch {
            app.present(error)
        }
    }

    var isRunning: Bool {
        app.preferences.activeTimer?.isRunning ?? false
    }

    var displayMilliseconds: Int64 {
        mode == .timer ? remainingMilliseconds : elapsedMilliseconds
    }

    var recentMaterialPairs: [(Material, Subject)] {
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        return materials.compactMap { material in
            guard let subject = subjectMap[material.subjectId] else { return nil }
            return (material, subject)
        }
    }

    var effectiveSelectedSubjectId: Int64? {
        resolvedSubjectId(activeTimer: app.preferences.activeTimer)
    }

    func materialsForSelectedSubject() -> [Material] {
        guard let subjectId = effectiveSelectedSubjectId else { return [] }
        return materials.filter { $0.subjectId == subjectId }
    }

    func startOrResume() {
        perform {
            guard let subjectId = self.effectiveSelectedSubjectId else {
                throw ValidationError(message: "科目を選択してください")
            }
            let current = self.app.preferences.activeTimer
            let now = Date().epochMilliseconds
            let completedIntervals = if let current, current.accumulatedMilliseconds > 0, current.completedIntervals.isEmpty {
                [StudySessionInterval(startTime: now - current.accumulatedMilliseconds, endTime: now)]
            } else {
                current?.completedIntervals ?? []
            }
            let next = TimerSnapshot(
                subjectId: subjectId,
                materialId: self.selectedMaterialId,
                startedAt: now,
                accumulatedMilliseconds: completedIntervals.reduce(0) { $0 + $1.duration },
                completedIntervals: completedIntervals,
                mode: self.mode,
                targetDurationMilliseconds: self.mode == .timer ? Int64(self.countdownMinutes * 60_000) : nil,
                problemRecords: ProblemSessionReviewResolver.canonicalInputRecords(current?.problemRecords ?? self.timerProblemRecords),
                problemCountDraft: current?.problemCountDraft ?? self.timerProblemCountDraft,
                isRunning: true
            )
            self.app.updateActiveTimer(next)
            self.timerProblemRecords = next.problemRecords
            self.timerProblemCountDraft = next.problemCountDraft
            self.elapsedMilliseconds = next.elapsedTime()
            self.remainingMilliseconds = next.remainingTime()
            self.configureTicker()
        }
    }

    func pause() {
        guard var timer = app.preferences.activeTimer else { return }
        let now = Date().epochMilliseconds
        if timer.isRunning, let startedAt = timer.startedAt {
            timer.completedIntervals.append(
                StudySessionInterval(
                    startTime: startedAt,
                    endTime: now
                )
            )
        }
        timer.accumulatedMilliseconds = timer.completedIntervals.reduce(0) { $0 + $1.duration }
        timer.startedAt = nil
        timer.isRunning = false
        app.updateActiveTimer(timer)
        elapsedMilliseconds = timer.accumulatedMilliseconds
        remainingMilliseconds = timer.remainingTime()
        configureTicker()
    }

    func setMode(_ newMode: TimerSnapshot.Mode) {
        guard !isRunning else {
            app.present("実行中はタイマー種別を変更できません")
            return
        }
        mode = newMode
        if var timer = app.preferences.activeTimer {
            timer.mode = newMode
            timer.targetDurationMilliseconds = newMode == .timer ? Int64(countdownMinutes * 60_000) : nil
            app.updateActiveTimer(timer)
        }
        remainingMilliseconds = newMode == .timer ? Int64(countdownMinutes * 60_000) : 0
    }

    func setCountdownMinutes(_ minutes: Int) {
        guard !isRunning else {
            app.present("実行中は時間を変更できません")
            return
        }
        countdownMinutes = minutes
        remainingMilliseconds = mode == .timer ? Int64(minutes * 60_000) : 0
        if var timer = app.preferences.activeTimer {
            timer.targetDurationMilliseconds = mode == .timer ? Int64(minutes * 60_000) : nil
            app.updateActiveTimer(timer)
        }
    }

    func handleSubjectSelectionChange() {
        selectedSubjectId = effectiveSelectedSubjectId
        selectedMaterialId = resolveSelectedMaterialId(activeTimer: app.preferences.activeTimer, subjectId: selectedSubjectId)
        if app.preferences.activeTimer == nil {
            timerProblemRecords = []
            timerProblemCountDraft = ""
        }
        syncActiveTimerSelection()
    }

    func handleMaterialSelectionChange() {
        selectedMaterialId = resolveSelectedMaterialId(activeTimer: app.preferences.activeTimer, subjectId: selectedSubjectId)
        if app.preferences.activeTimer == nil {
            timerProblemRecords = []
            timerProblemCountDraft = ""
        }
        syncActiveTimerSelection()
    }

    func stop() {
        perform {
            guard self.pendingSessionEvaluation == nil else { return }
            guard let timer = self.finalizeTimerForEvaluation() else { return }
            let elapsed = timer.accumulatedMilliseconds
            guard elapsed > 0 else {
                self.app.updateActiveTimer(nil)
                self.elapsedMilliseconds = 0
                self.remainingMilliseconds = 0
                self.configureTicker()
                return
            }
            guard let subject = try await self.app.subjectRepo.getSubjectById(timer.subjectId) else {
                throw ValidationError(message: "科目を選択してください")
            }
            let materials = try await self.app.materialRepo.getAllMaterials()
            let materialId = timer.materialId
            let material = materials.first(where: { $0.id == materialId })
            let materialName = material?.name ?? ""
            let intervals = timer.finalizedIntervals()
            let start = intervals.first?.startTime ?? (Date().epochMilliseconds - elapsed)
            let end = intervals.last?.endTime ?? Date().epochMilliseconds
            self.pendingSessionEvaluation = PendingSessionEvaluation(
                session: StudySession(
                    materialId: materialId,
                    materialSyncId: material?.syncId,
                    materialName: materialName,
                    subjectId: subject.id,
                    subjectSyncId: subject.syncId,
                    subjectName: subject.name,
                    sessionType: timer.sessionType,
                    startTime: start,
                    endTime: end,
                    intervals: intervals,
                    problemRecords: ProblemSessionReviewResolver.canonicalInputRecords(timer.problemRecords)
                )
            )
        }
    }

    func updateTimerProblemRecords(_ records: [ProblemSessionRecord], totalProblems: Int) {
        let normalizedRecords = ProblemSessionReviewResolver.canonicalInputRecords(records)
            .filter { totalProblems <= 0 || $0.number <= totalProblems }
        timerProblemRecords = normalizedRecords
        guard var timer = app.preferences.activeTimer else { return }
        timer.problemRecords = normalizedRecords
        app.updateActiveTimer(timer)
    }

    func updateTimerProblemCountDraft(_ draft: String, totalProblems: Int) {
        timerProblemCountDraft = draft
        if totalProblems > 0 {
            timerProblemRecords.removeAll { $0.number > totalProblems }
        }
        guard var timer = app.preferences.activeTimer else { return }
        timer.problemCountDraft = draft
        timer.problemRecords = timerProblemRecords
        app.updateActiveTimer(timer)
    }

    func savePendingSessionEvaluation(
        rating: Int,
        note: String?,
        problemRecords: [ProblemSessionRecord],
        totalProblems: Int,
        problemStart: Int?,
        problemEnd: Int?,
        wrongProblemCount: Int?
    ) {
        perform {
            try TimerProblemValidation.validateRating(rating)
            let normalizedRecords = ProblemSessionReviewResolver.canonicalInputRecords(problemRecords)
            try TimerProblemValidation.validate(
                problemStart: normalizedRecords.first?.number ?? problemStart,
                problemEnd: normalizedRecords.last?.number ?? problemEnd,
                wrongProblemCount: normalizedRecords.isEmpty ? wrongProblemCount : normalizedRecords.filter(\.isWrong).count
            )
            guard var draft = self.pendingSessionEvaluation else { return }
            draft.session.rating = rating
            draft.session.note = note?.nilIfBlank
            draft.session.problemRecords = normalizedRecords
            draft.session.problemStart = normalizedRecords.first?.number ?? problemStart
            draft.session.problemEnd = normalizedRecords.last?.number ?? problemEnd
            draft.session.wrongProblemCount = normalizedRecords.isEmpty ? wrongProblemCount : normalizedRecords.filter(\.isWrong).count
            if totalProblems > 0, let materialId = draft.session.materialId {
                let materials = try await self.app.materialRepo.getAllMaterials()
                if var material = materials.first(where: { $0.id == materialId }) {
                    let storedTotalProblems = material.totalProblems
                    material.totalProblems = totalProblems
                    if storedTotalProblems != totalProblems {
                        try await self.app.materialRepo.updateMaterial(material)
                    }
                    if let index = self.materials.firstIndex(where: { $0.id == materialId }) {
                        self.materials[index] = material
                    }
                }
            }
            _ = try await self.app.sessionRepo.insertSessionWithProblemReviews(draft.session)
            self.pendingSessionEvaluation = nil
            self.app.updateActiveTimer(nil)
            self.timerProblemRecords = []
            self.timerProblemCountDraft = ""
            self.elapsedMilliseconds = 0
            self.remainingMilliseconds = 0
            self.configureTicker()
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func cancelPendingSessionEvaluation() {
        pendingSessionEvaluation = nil
    }

    func saveManualSession(
        subjectId: Int64,
        materialId: Int64?,
        startTime: Int64,
        endTime: Int64,
        note: String?,
        rating: Int? = nil,
        problemRecords: [ProblemSessionRecord] = [],
        problemStart: Int? = nil,
        problemEnd: Int? = nil,
        wrongProblemCount: Int? = nil
    ) {
        perform {
            guard let subject = try await self.app.subjectRepo.getSubjectById(subjectId) else {
                throw ValidationError(message: "科目を選択してください")
            }
            let duration = endTime - startTime
            guard duration > 0 else {
                throw ValidationError(message: "終了時刻は開始時刻より後にしてください")
            }
            if let rating {
                try TimerProblemValidation.validateRating(rating)
            }
            let normalizedRecords = ProblemSessionReviewResolver.canonicalInputRecords(problemRecords)
            try TimerProblemValidation.validate(
                problemStart: normalizedRecords.first?.number ?? problemStart,
                problemEnd: normalizedRecords.last?.number ?? problemEnd,
                wrongProblemCount: normalizedRecords.isEmpty ? wrongProblemCount : normalizedRecords.filter(\.isWrong).count
            )
            let materials = try await self.app.materialRepo.getAllMaterials()
            let material = materials.first(where: { $0.id == materialId })
            _ = try await self.app.sessionRepo.insertSessionWithProblemReviews(
                StudySession(
                    materialId: materialId,
                    materialSyncId: material?.syncId,
                    materialName: material?.name ?? "",
                    subjectId: subject.id,
                    subjectSyncId: subject.syncId,
                    subjectName: subject.name,
                    sessionType: .manual,
                    startTime: startTime,
                    endTime: endTime,
                    intervals: [StudySessionInterval(startTime: startTime, endTime: endTime)],
                    rating: rating,
                    note: note?.nilIfBlank,
                    problemStart: normalizedRecords.first?.number ?? problemStart,
                    problemEnd: normalizedRecords.last?.number ?? problemEnd,
                    wrongProblemCount: normalizedRecords.isEmpty ? wrongProblemCount : normalizedRecords.filter(\.isWrong).count,
                    problemRecords: normalizedRecords
                )
            )
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    private func validateProblemRecord(problemStart: Int?, problemEnd: Int?, wrongProblemCount: Int?) throws {
        try TimerProblemValidation.validate(
            problemStart: problemStart,
            problemEnd: problemEnd,
            wrongProblemCount: wrongProblemCount
        )
    }

    private func configureTicker() {
        cancellable?.cancel()
        guard app.preferences.activeTimer?.isRunning == true else { return }
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedMilliseconds = self.app.preferences.activeTimer?.elapsedTime() ?? 0
                self.remainingMilliseconds = self.app.preferences.activeTimer?.remainingTime() ?? 0
                self.refreshScreenTimeGoalProgressIfNeeded()
                if self.mode == .timer, self.remainingMilliseconds <= 0 {
                    self.stop()
                }
            }
    }

    private func refreshScreenTimeGoalProgressIfNeeded() {
        guard app.screenTimeFocusController.settings.isEnabled,
              app.screenTimeFocusController.settings.unlockRestrictionsWhenDailyGoalReached else {
            return
        }
        let currentMinute = elapsedMilliseconds / 60_000
        guard currentMinute > 0, currentMinute != lastScreenTimeGoalSyncMinute else { return }
        lastScreenTimeGoalSyncMinute = currentMinute
        Task { await self.app.refreshScreenTimeFocusState(reason: "active-timer-progress") }
    }

    private func finalizeTimerForEvaluation() -> TimerSnapshot? {
        guard var timer = app.preferences.activeTimer else { return nil }
        let now = Date().epochMilliseconds
        if timer.isRunning, let startedAt = timer.startedAt {
            timer.completedIntervals.append(
                StudySessionInterval(
                    startTime: startedAt,
                    endTime: now
                )
            )
        }
        timer.accumulatedMilliseconds = timer.completedIntervals.reduce(0) { $0 + $1.duration }
        timer.startedAt = nil
        timer.isRunning = false
        app.updateActiveTimer(timer)
        elapsedMilliseconds = timer.accumulatedMilliseconds
        remainingMilliseconds = timer.remainingTime()
        configureTicker()
        app.screenTimeFocusController.clearTimerRestriction()
        return timer
    }

    private func resolvedSubjectId(activeTimer: TimerSnapshot?) -> Int64? {
        if let selectedSubjectId, subjects.contains(where: { $0.id == selectedSubjectId }) {
            return selectedSubjectId
        }
        if let timerSubjectId = activeTimer?.subjectId, subjects.contains(where: { $0.id == timerSubjectId }) {
            return timerSubjectId
        }
        return subjects.first?.id
    }

    private func resolveSelectedSubjectId(activeTimer: TimerSnapshot?) -> Int64? {
        resolvedSubjectId(activeTimer: activeTimer)
    }

    private func resolveSelectedMaterialId(activeTimer: TimerSnapshot?, subjectId: Int64?) -> Int64? {
        guard let subjectId else { return nil }
        let availableMaterials = materials.filter { $0.subjectId == subjectId }

        if let selectedMaterialId, availableMaterials.contains(where: { $0.id == selectedMaterialId }) {
            return selectedMaterialId
        }
        if let timerMaterialId = activeTimer?.materialId,
           availableMaterials.contains(where: { $0.id == timerMaterialId }) {
            return timerMaterialId
        }
        return nil
    }

    private func syncActiveTimerSelection() {
        guard var timer = app.preferences.activeTimer else { return }
        guard let subjectId = effectiveSelectedSubjectId else { return }

        let materialId = selectedMaterialId
        guard timer.subjectId != subjectId || timer.materialId != materialId else { return }

        let materialChanged = timer.materialId != materialId
        timer.subjectId = subjectId
        timer.materialId = materialId
        timer.mode = mode
        timer.targetDurationMilliseconds = mode == .timer ? Int64(countdownMinutes * 60_000) : nil
        if materialChanged {
            timer.problemRecords = []
            timer.problemCountDraft = ""
            timerProblemRecords = []
            timerProblemCountDraft = ""
        }
        app.updateActiveTimer(timer)
    }
}
