import Combine
import Foundation

@MainActor
final class StudyAppStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot = .empty
    @Published private(set) var isLoaded = false
    @Published var errorMessage: String?
    @Published var bookSearchResult: BookInfo?
    @Published private(set) var elapsedTime: TimeInterval = 0

    private let persistence: PersistenceController
    private let googleBooksService: GoogleBooksService
    private let reminderScheduler: ReminderScheduler
    private var timerCancellable: AnyCancellable?

    init(
        persistence: PersistenceController = .shared,
        googleBooksService: GoogleBooksService = GoogleBooksService(),
        reminderScheduler: ReminderScheduler = ReminderScheduler()
    ) {
        self.persistence = persistence
        self.googleBooksService = googleBooksService
        self.reminderScheduler = reminderScheduler

        Task {
            await load()
        }
    }

    var subjects: [Subject] {
        snapshot.subjects.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var materials: [Material] {
        snapshot.materials.sorted { lhs, rhs in
            if lhs.id == rhs.id {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.id > rhs.id
        }
    }

    var sessions: [StudySession] {
        snapshot.sessions.sorted { $0.startTime > $1.startTime }
    }

    var exams: [Exam] {
        snapshot.exams.sorted { $0.date < $1.date }
    }

    var goals: [Goal] {
        snapshot.goals
    }

    var plans: [StudyPlan] {
        snapshot.plans.sorted { $0.createdAt > $1.createdAt }
    }

    var planItems: [PlanItem] {
        snapshot.planItems
    }

    var onboardingCompleted: Bool {
        snapshot.onboardingCompleted
    }

    var reminderEnabled: Bool {
        snapshot.reminderEnabled
    }

    var reminderHour: Int {
        snapshot.reminderHour
    }

    var reminderMinute: Int {
        snapshot.reminderMinute
    }

    var reminderTimeString: String {
        String(format: "%02d:%02d", snapshot.reminderHour, snapshot.reminderMinute)
    }

    var selectedColorTheme: ColorTheme {
        snapshot.selectedColorTheme
    }

    var selectedThemeMode: ThemeMode {
        snapshot.selectedThemeMode
    }

    var activePlan: StudyPlan? {
        snapshot.plans.first(where: \.isActive)
    }

    var activeDailyGoal: Goal? {
        snapshot.goals.first(where: { $0.type == .daily && $0.isActive })
    }

    var activeWeeklyGoal: Goal? {
        snapshot.goals.first(where: { $0.type == .weekly && $0.isActive })
    }

    func load() async {
        do {
            var loaded = try await persistence.load()
            snapshot = loaded
            recalculatePlanActualMinutes()
            loaded = snapshot
            try await persistence.save(snapshot: loaded)
            isLoaded = true
            restoreTimerState()
        } catch {
            snapshot = .empty
            isLoaded = true
            present(error)
        }
    }

    func completeOnboarding() {
        snapshot.onboardingCompleted = true
        persist()
    }

    func setColorTheme(_ theme: ColorTheme) {
        snapshot.selectedColorTheme = theme
        persist()
    }

    func setThemeMode(_ mode: ThemeMode) {
        snapshot.selectedThemeMode = mode
        persist()
    }

    func setReminderEnabled(_ enabled: Bool) async {
        if enabled {
            do {
                let granted = try await reminderScheduler.requestAuthorizationIfNeeded()
                guard granted else {
                    present("通知の許可が必要です")
                    return
                }
                try await reminderScheduler.scheduleDailyReminder(
                    hour: snapshot.reminderHour,
                    minute: snapshot.reminderMinute
                )
                snapshot.reminderEnabled = true
            } catch {
                present(error)
                return
            }
        } else {
            reminderScheduler.cancelReminder()
            snapshot.reminderEnabled = false
        }
        persist()
    }

    func setReminderTime(hour: Int, minute: Int) async {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            present("時刻の形式が正しくありません")
            return
        }

        snapshot.reminderHour = hour
        snapshot.reminderMinute = minute
        if snapshot.reminderEnabled {
            do {
                try await reminderScheduler.scheduleDailyReminder(hour: hour, minute: minute)
            } catch {
                present(error)
                return
            }
        }
        persist()
    }

    func subject(for id: Int64) -> Subject? {
        snapshot.subjects.first(where: { $0.id == id })
    }

    func material(for id: Int64?) -> Material? {
        guard let id else { return nil }
        return snapshot.materials.first(where: { $0.id == id })
    }

    func materials(for subjectId: Int64) -> [Material] {
        materials.filter { $0.subjectId == subjectId }
    }

    func planItems(for planId: Int64) -> [PlanItem] {
        snapshot.planItems
            .filter { $0.planId == planId }
            .sorted { lhs, rhs in
                if lhs.dayOfWeek == rhs.dayOfWeek {
                    return lhs.targetMinutes > rhs.targetMinutes
                }
                return StudyWeekday.allCases.firstIndex(of: lhs.dayOfWeek) ?? 0
                    < StudyWeekday.allCases.firstIndex(of: rhs.dayOfWeek) ?? 0
            }
    }

    func weeklySchedule(for plan: StudyPlan) -> [StudyWeekday: [PlanItemWithSubject]] {
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        return Dictionary(uniqueKeysWithValues: StudyWeekday.allCases.map { weekday in
            let items = planItems(for: plan.id)
                .filter { $0.dayOfWeek == weekday }
                .compactMap { item -> PlanItemWithSubject? in
                    guard let subject = subjectMap[item.subjectId] else { return nil }
                    return PlanItemWithSubject(item: item, subject: subject)
                }
            return (weekday, items)
        })
    }

    var subjectStudyMinutes: [Int64: Int] {
        snapshot.sessions.reduce(into: [Int64: Int]()) { result, session in
            result[session.subjectId, default: 0] += session.durationMinutes
        }
    }

    func todayStudyMinutes(reference: Date = Date()) -> Int {
        sessions(on: reference).reduce(0) { $0 + $1.durationMinutes }
    }

    func weeklyStudyMinutes(reference: Date = Date()) -> Int {
        let range = weekRange(containing: reference)
        return sessions(in: range.start...range.end).reduce(0) { $0 + $1.durationMinutes }
    }

    func recentSessions(limit: Int = 3) -> [StudySession] {
        Array(sessions.prefix(limit))
    }

    func recentMaterials(limit: Int = 5) -> [(Material, Subject)] {
        let materialIds = sessions
            .compactMap(\.materialId)
            .reduce(into: [Int64]()) { result, materialId in
                if !result.contains(materialId) {
                    result.append(materialId)
                }
            }
            .prefix(limit)

        return materialIds.compactMap { materialId in
            guard let material = material(for: materialId), let subject = subject(for: material.subjectId) else {
                return nil
            }
            return (material, subject)
        }
    }

    func upcomingExams(limit: Int? = nil) -> [Exam] {
        let filtered = exams.filter { !$0.isPast() }.sorted { $0.date < $1.date }
        if let limit {
            return Array(filtered.prefix(limit))
        }
        return filtered
    }

    func addSubject(name: String, color: Int, icon: SubjectIcon?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("科目名を入力してください")
            return
        }

        snapshot.subjects.append(Subject(id: nextIdentifier(), name: trimmed, color: color, icon: icon))
        persist()
    }

    func updateSubject(_ subject: Subject) {
        let trimmed = subject.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("科目名を入力してください")
            return
        }
        guard let index = snapshot.subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        snapshot.subjects[index] = Subject(id: subject.id, name: trimmed, color: subject.color, icon: subject.icon)
        snapshot.sessions = snapshot.sessions.map { session in
            guard session.subjectId == subject.id else { return session }
            var updated = session
            updated.subjectName = trimmed
            return updated
        }
        persist()
    }

    func deleteSubject(_ subject: Subject) {
        let materialIds = snapshot.materials.filter { $0.subjectId == subject.id }.map(\.id)
        snapshot.subjects.removeAll { $0.id == subject.id }
        snapshot.materials.removeAll { $0.subjectId == subject.id }
        snapshot.sessions.removeAll { $0.subjectId == subject.id || ($0.materialId.map(materialIds.contains) ?? false) }
        snapshot.planItems.removeAll { $0.subjectId == subject.id }
        recalculatePlanActualMinutes()
        persist()
    }

    func addMaterial(name: String, subjectId: Int64, totalPages: Int, color: Int? = nil, note: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("教材名を入力してください")
            return
        }
        guard subject(for: subjectId) != nil else {
            present("科目を選択してください")
            return
        }
        guard totalPages >= 0 else {
            present("ページ数は0以上で入力してください")
            return
        }

        snapshot.materials.append(
            Material(
                id: nextIdentifier(),
                name: trimmed,
                subjectId: subjectId,
                totalPages: totalPages,
                currentPage: 0,
                color: color,
                note: note?.nilIfBlank
            )
        )
        persist()
    }

    func updateMaterial(_ material: Material) {
        let trimmed = material.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("教材名を入力してください")
            return
        }
        guard subject(for: material.subjectId) != nil else {
            present("科目を選択してください")
            return
        }
        guard material.totalPages >= 0 else {
            present("ページ数は0以上で入力してください")
            return
        }
        guard material.currentPage <= material.totalPages || material.totalPages == 0 else {
            present("現在のページは総ページ数以下にしてください")
            return
        }
        guard let index = snapshot.materials.firstIndex(where: { $0.id == material.id }) else { return }
        snapshot.materials[index] = Material(
            id: material.id,
            name: trimmed,
            subjectId: material.subjectId,
            totalPages: material.totalPages,
            currentPage: material.currentPage,
            color: material.color,
            note: material.note?.nilIfBlank
        )
        snapshot.sessions = snapshot.sessions.map { session in
            guard session.materialId == material.id else { return session }
            var updated = session
            updated.materialName = trimmed
            if let subject = subject(for: material.subjectId) {
                updated.subjectId = subject.id
                updated.subjectName = subject.name
            }
            return updated
        }
        persist()
    }

    func deleteMaterial(_ material: Material) {
        snapshot.materials.removeAll { $0.id == material.id }
        snapshot.sessions.removeAll { $0.materialId == material.id }
        persist()
    }

    func updateMaterialProgress(materialId: Int64, page: Int) {
        guard page >= 0 else {
            present("ページ数は0以上で入力してください")
            return
        }
        guard let index = snapshot.materials.firstIndex(where: { $0.id == materialId }) else {
            present("教材が見つかりません")
            return
        }
        let material = snapshot.materials[index]
        guard material.totalPages == 0 || page <= material.totalPages else {
            present("現在のページは総ページ数以下にしてください")
            return
        }
        snapshot.materials[index].currentPage = page
        persist()
    }

    func searchBookByIsbn(_ isbn: String) async {
        let trimmed = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("ISBNを入力してください")
            return
        }
        do {
            bookSearchResult = try await googleBooksService.searchByIsbn(trimmed)
        } catch {
            present(error)
        }
    }

    func clearSearchResult() {
        bookSearchResult = nil
    }

    func addMaterial(from bookInfo: BookInfo, subjectId: Int64) {
        let note = buildBookNote(bookInfo)
        addMaterial(
            name: bookInfo.title,
            subjectId: subjectId,
            totalPages: bookInfo.pageCount ?? 0,
            note: note
        )
        bookSearchResult = nil
    }

    func addExam(name: String, date: Date, note: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("テスト名を入力してください")
            return
        }
        snapshot.exams.append(
            Exam(id: nextIdentifier(), name: trimmed, date: Calendar.current.startOfDay(for: date), note: note?.nilIfBlank)
        )
        persist()
    }

    func updateExam(_ exam: Exam) {
        let trimmed = exam.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("テスト名を入力してください")
            return
        }
        guard let index = snapshot.exams.firstIndex(where: { $0.id == exam.id }) else { return }
        snapshot.exams[index] = Exam(
            id: exam.id,
            name: trimmed,
            date: Calendar.current.startOfDay(for: exam.date),
            note: exam.note?.nilIfBlank
        )
        persist()
    }

    func deleteExam(_ exam: Exam) {
        snapshot.exams.removeAll { $0.id == exam.id }
        persist()
    }

    func updateGoal(type: GoalType, targetMinutes: Int) {
        guard targetMinutes > 0 else {
            present("目標時間は0より大きくしてください")
            return
        }

        if let index = snapshot.goals.firstIndex(where: { $0.type == type && $0.isActive }) {
            snapshot.goals[index].targetMinutes = targetMinutes
        } else {
            snapshot.goals = snapshot.goals.map { goal in
                var updated = goal
                if updated.type == type {
                    updated.isActive = false
                }
                return updated
            }
            snapshot.goals.append(
                Goal(
                    id: nextIdentifier(),
                    type: type,
                    targetMinutes: targetMinutes,
                    weekStartDay: .monday,
                    isActive: true
                )
            )
        }
        persist()
    }

    func sessions(on date: Date) -> [StudySession] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return sessions.filter { $0.startTime >= start && $0.startTime < end }
    }

    func sessions(in range: ClosedRange<Date>) -> [StudySession] {
        sessions.filter { range.contains($0.startTime) }
    }

    func saveManualSession(subjectId: Int64, materialId: Int64?, durationMinutes: Int, note: String? = nil) {
        guard durationMinutes > 0 else {
            present("学習時間は0より大きくしてください")
            return
        }
        guard let subject = subject(for: subjectId) else {
            present("科目を選択してください")
            return
        }
        let now = Date()
        let durationSeconds = TimeInterval(durationMinutes * 60)
        let session = StudySession(
            id: nextIdentifier(),
            materialId: materialId,
            materialName: material(for: materialId)?.name ?? "",
            subjectId: subject.id,
            subjectName: subject.name,
            startTime: now.addingTimeInterval(-durationSeconds),
            endTime: now,
            note: note?.nilIfBlank
        )
        snapshot.sessions.append(session)
        recalculatePlanActualMinutes()
        persist()
    }

    func updateSession(id: Int64, durationMinutes: Int, note: String?) {
        guard durationMinutes > 0 else {
            present("学習時間は0より大きくしてください")
            return
        }
        guard let index = snapshot.sessions.firstIndex(where: { $0.id == id }) else { return }
        snapshot.sessions[index].endTime = snapshot.sessions[index].startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
        snapshot.sessions[index].note = note?.nilIfBlank
        recalculatePlanActualMinutes()
        persist()
    }

    func deleteSession(_ session: StudySession) {
        snapshot.sessions.removeAll { $0.id == session.id }
        recalculatePlanActualMinutes()
        persist()
    }

    func startTimer(subjectId: Int64, materialId: Int64?) {
        guard subject(for: subjectId) != nil else {
            present("科目を選択してください")
            return
        }
        if var activeTimer = snapshot.activeTimer {
            activeTimer.subjectId = subjectId
            activeTimer.materialId = materialId
            activeTimer.startedAt = Date()
            activeTimer.isRunning = true
            snapshot.activeTimer = activeTimer
        } else {
            snapshot.activeTimer = TimerSnapshot(
                subjectId: subjectId,
                materialId: materialId,
                startedAt: Date(),
                accumulatedSeconds: 0,
                isRunning: true
            )
        }
        startTicker()
        updateElapsedTime()
        persist()
    }

    func pauseTimer() {
        guard var activeTimer = snapshot.activeTimer, activeTimer.isRunning, let startedAt = activeTimer.startedAt else {
            return
        }
        activeTimer.accumulatedSeconds += Date().timeIntervalSince(startedAt)
        activeTimer.startedAt = nil
        activeTimer.isRunning = false
        snapshot.activeTimer = activeTimer
        stopTicker()
        elapsedTime = activeTimer.accumulatedSeconds
        persist()
    }

    func stopTimer(note: String? = nil) {
        guard let activeTimer = snapshot.activeTimer else { return }
        let duration = activeTimer.elapsedTime()
        guard duration > 0 else {
            snapshot.activeTimer = nil
            elapsedTime = 0
            stopTicker()
            persist()
            return
        }
        guard let subject = subject(for: activeTimer.subjectId) else {
            present("科目を選択してください")
            return
        }
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-duration)
        snapshot.sessions.append(
            StudySession(
                id: nextIdentifier(),
                materialId: activeTimer.materialId,
                materialName: material(for: activeTimer.materialId)?.name ?? "",
                subjectId: subject.id,
                subjectName: subject.name,
                startTime: startTime,
                endTime: endTime,
                note: note?.nilIfBlank
            )
        )
        snapshot.activeTimer = nil
        elapsedTime = 0
        stopTicker()
        recalculatePlanActualMinutes()
        persist()
    }

    func createPlan(name: String, startDate: Date, endDate: Date, items: [PlanItem]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            present("プラン名を入力してください")
            return
        }
        guard startDate < endDate else {
            present("開始日は終了日より前に設定してください")
            return
        }
        guard !items.isEmpty else {
            present("少なくとも1つの学習項目を追加してください")
            return
        }

        snapshot.plans = snapshot.plans.map { plan in
            var updated = plan
            updated.isActive = false
            return updated
        }

        let newPlanId = nextIdentifier()
        let plan = StudyPlan(
            id: newPlanId,
            name: trimmed,
            startDate: Calendar.current.startOfDay(for: startDate),
            endDate: Calendar.current.startOfDay(for: endDate),
            isActive: true,
            createdAt: Date()
        )
        snapshot.plans.append(plan)
        snapshot.planItems.removeAll { existing in
            snapshot.plans.contains(where: { $0.id == existing.planId && $0.isActive })
        }
        snapshot.planItems.append(contentsOf: items.map { item in
            PlanItem(
                id: nextIdentifier(),
                planId: newPlanId,
                subjectId: item.subjectId,
                dayOfWeek: item.dayOfWeek,
                targetMinutes: item.targetMinutes,
                actualMinutes: item.actualMinutes,
                timeSlot: item.timeSlot?.nilIfBlank
            )
        })
        recalculatePlanActualMinutes()
        persist()
    }

    func addPlanItem(subjectId: Int64, dayOfWeek: StudyWeekday, targetMinutes: Int, timeSlot: String?) {
        guard let activePlan else { return }
        guard targetMinutes > 0 else {
            present("目標時間は0より大きくしてください")
            return
        }
        snapshot.planItems.append(
            PlanItem(
                id: nextIdentifier(),
                planId: activePlan.id,
                subjectId: subjectId,
                dayOfWeek: dayOfWeek,
                targetMinutes: targetMinutes,
                actualMinutes: 0,
                timeSlot: timeSlot?.nilIfBlank
            )
        )
        recalculatePlanActualMinutes()
        persist()
    }

    func updatePlanItem(_ item: PlanItem) {
        guard item.targetMinutes > 0 else {
            present("目標時間は0より大きくしてください")
            return
        }
        guard let index = snapshot.planItems.firstIndex(where: { $0.id == item.id }) else { return }
        snapshot.planItems[index] = item
        recalculatePlanActualMinutes()
        persist()
    }

    func deletePlanItem(_ item: PlanItem) {
        snapshot.planItems.removeAll { $0.id == item.id }
        recalculatePlanActualMinutes()
        persist()
    }

    func deleteActivePlan() {
        guard let activePlan else { return }
        snapshot.planItems.removeAll { $0.planId == activePlan.id }
        snapshot.plans.removeAll { $0.id == activePlan.id }
        persist()
    }

    func completionRate(for plan: StudyPlan) -> Double {
        let items = planItems(for: plan.id)
        let totalTarget = items.reduce(0) { $0 + $1.targetMinutes }
        let totalActual = items.reduce(0) { $0 + $1.actualMinutes }
        guard totalTarget > 0 else { return 0 }
        return min(Double(totalActual) / Double(totalTarget), 1)
    }

    func weeklyPlanSummary(for plan: StudyPlan) -> WeeklyPlanSummary {
        let items = planItems(for: plan.id)
        let daySummaries = Dictionary(uniqueKeysWithValues: StudyWeekday.allCases.map { day in
            let dayItems = items.filter { $0.dayOfWeek == day }
            let target = dayItems.reduce(0) { $0 + $1.targetMinutes }
            let actual = dayItems.reduce(0) { $0 + $1.actualMinutes }
            return (day, DailyPlanSummary(dayOfWeek: day, targetMinutes: target, actualMinutes: actual))
        })
        return WeeklyPlanSummary(
            weekStart: weekRange(containing: Date()).start,
            weekEnd: weekRange(containing: Date()).end,
            totalTargetMinutes: items.reduce(0) { $0 + $1.targetMinutes },
            totalActualMinutes: items.reduce(0) { $0 + $1.actualMinutes },
            dailyBreakdown: daySummaries
        )
    }

    func monthlyStudyMap(year: Int, month: Int) -> [Int: Int] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let calendar = Calendar.current
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return [:]
        }
        let monthSessions = sessions(in: start...end)
        return monthSessions.reduce(into: [Int: Int]()) { result, session in
            let day = calendar.component(.day, from: session.startTime)
            result[day, default: 0] += session.durationMinutes
        }
    }

    func reportDailyData(reference: Date = Date()) -> [DailyStudyData] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: reference) else { return nil }
            let minutes = sessions(on: date).reduce(0) { $0 + $1.durationMinutes }
            return DailyStudyData(
                date: calendar.startOfDay(for: date),
                dateLabel: formatter.string(from: date),
                minutes: minutes,
                hours: Double(minutes) / 60.0
            )
        }
        .reversed()
    }

    func reportWeeklyData(reference: Date = Date()) -> [WeeklyStudyData] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return (0..<4).compactMap { offset in
            guard let date = calendar.date(byAdding: .weekOfYear, value: -offset, to: reference) else { return nil }
            let range = weekRange(containing: date)
            let minutes = sessions(in: range.start...range.end).reduce(0) { $0 + $1.durationMinutes }
            return WeeklyStudyData(
                weekStart: range.start,
                weekLabel: "\(formatter.string(from: range.start))週",
                hours: minutes / 60,
                minutes: minutes % 60
            )
        }
        .reversed()
    }

    func reportMonthlyData(reference: Date = Date()) -> [MonthlyStudyData] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月"
        return (0..<6).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: reference),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
                return nil
            }
            let minutes = sessions(in: monthInterval.start...monthInterval.end).reduce(0) { $0 + $1.durationMinutes }
            return MonthlyStudyData(
                monthStart: monthInterval.start,
                monthLabel: formatter.string(from: monthInterval.start),
                totalHours: minutes / 60
            )
        }
        .reversed()
    }

    func subjectBreakdown(reference: Date = Date()) -> [SubjectStudyData] {
        let calendar = Calendar.current
        guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: reference) else {
            return []
        }
        return subjects.compactMap { subject in
            let minutes = sessions
                .filter { $0.subjectId == subject.id && $0.startTime >= monthAgo && $0.startTime <= reference }
                .reduce(0) { $0 + $1.durationMinutes }
            guard minutes > 0 else { return nil }
            return SubjectStudyData(
                subjectName: subject.name,
                hours: minutes / 60,
                minutes: minutes % 60,
                color: subject.color
            )
        }
        .sorted { ($0.hours * 60 + $0.minutes) > ($1.hours * 60 + $1.minutes) }
    }

    func streakDays(reference: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var current = calendar.startOfDay(for: reference)
        for index in 0..<365 {
            let total = sessions(on: current).reduce(0) { $0 + $1.durationMinutes }
            if total > 0 {
                streak += 1
            } else if index > 0 {
                break
            }
            current = calendar.date(byAdding: .day, value: -1, to: current) ?? current
        }
        return streak
    }

    func bestStreak() -> Int {
        let dayKeys = Set(sessions.map { Calendar.current.startOfDay(for: $0.startTime) })
        let sortedDates = dayKeys.sorted()
        guard var previous = sortedDates.first else { return 0 }
        var best = 1
        var current = 1
        for date in sortedDates.dropFirst() {
            let diff = Calendar.current.dateComponents([.day], from: previous, to: date).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
            previous = date
        }
        return best
    }

    func exportFile(format: ExportFormat) async -> URL? {
        do {
            let contents: String
            switch format {
            case .json:
                contents = try await persistence.exportJSON(from: snapshot)
            case .csv:
                contents = await persistence.exportCSV(from: snapshot)
            }

            let fileName = "studyapp_backup_\(timestampString()).\(format.rawValue)"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try contents.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            present(error)
            return nil
        }
    }

    func importBackup(from url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            guard let json = String(data: data, encoding: .utf8) else {
                present("バックアップの読み込みに失敗しました")
                return
            }
            let imported = try await persistence.importJSON(json, into: snapshot)
            snapshot = imported
            recalculatePlanActualMinutes()
            restoreTimerState()
            persist()
        } catch {
            present(error)
        }
    }

    func deleteAllData() {
        let reminderEnabled = snapshot.reminderEnabled
        let reminderHour = snapshot.reminderHour
        let reminderMinute = snapshot.reminderMinute
        let onboardingCompleted = snapshot.onboardingCompleted
        let selectedColorTheme = snapshot.selectedColorTheme
        let selectedThemeMode = snapshot.selectedThemeMode

        snapshot = AppSnapshot.empty
        snapshot.reminderEnabled = reminderEnabled
        snapshot.reminderHour = reminderHour
        snapshot.reminderMinute = reminderMinute
        snapshot.onboardingCompleted = onboardingCompleted
        snapshot.selectedColorTheme = selectedColorTheme
        snapshot.selectedThemeMode = selectedThemeMode
        elapsedTime = 0
        stopTicker()
        persist()
    }

    func clearError() {
        errorMessage = nil
    }

    private func restoreTimerState() {
        if let activeTimer = snapshot.activeTimer {
            elapsedTime = activeTimer.elapsedTime()
            if activeTimer.isRunning {
                startTicker()
            } else {
                stopTicker()
            }
        } else {
            elapsedTime = 0
            stopTicker()
        }
    }

    private func startTicker() {
        stopTicker()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateElapsedTime()
            }
    }

    private func stopTicker() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func updateElapsedTime() {
        elapsedTime = snapshot.activeTimer?.elapsedTime() ?? 0
    }

    private func recalculatePlanActualMinutes() {
        guard let activePlan else { return }
        snapshot.planItems = snapshot.planItems.map { item in
            guard item.planId == activePlan.id else { return item }
            var updated = item
            updated.actualMinutes = sessions
                .filter { session in
                    session.subjectId == item.subjectId &&
                    session.dayOfWeek == item.dayOfWeek &&
                    session.startTime >= activePlan.startDate &&
                    session.startTime <= activePlan.endDate
                }
                .reduce(0) { $0 + $1.durationMinutes }
            return updated
        }
    }

    private func weekRange(containing date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        let start = interval?.start ?? calendar.startOfDay(for: date)
        let end = interval?.end ?? start
        return (start, end)
    }

    private func nextIdentifier() -> Int64 {
        snapshot.lastIdentifier += 1
        return snapshot.lastIdentifier
    }

    private func persist() {
        let current = snapshot
        Task {
            do {
                try await persistence.save(snapshot: current)
            } catch {
                await MainActor.run {
                    self.present(error)
                }
            }
        }
    }

    private func buildBookNote(_ bookInfo: BookInfo) -> String? {
        var lines = [String]()
        if !bookInfo.authors.isEmpty {
            lines.append("著者: \(bookInfo.authors.joined(separator: ", "))")
        }
        if let publisher = bookInfo.publisher, !publisher.isEmpty {
            lines.append("出版社: \(publisher)")
        }
        if let publishedDate = bookInfo.publishedDate, !publishedDate.isEmpty {
            lines.append("出版日: \(publishedDate)")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func present(_ message: String) {
        errorMessage = message
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
