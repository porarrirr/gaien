import Combine
import Foundation

@MainActor
final class PlanViewModel: ScreenViewModel {
    @Published private(set) var plans: [StudyPlan] = []
    @Published private(set) var activePlan: StudyPlan?
    @Published private(set) var planItems: [PlanItem] = []
    @Published private(set) var subjects: [Subject] = []
    @Published var selectedDay: StudyWeekday?

    var weeklySchedule: [StudyWeekday: [PlanItemWithSubject]] {
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        return Dictionary(uniqueKeysWithValues: StudyWeekday.allCases.map { day in
            let dayItems = planItems
                .filter { $0.dayOfWeek == day }
                .compactMap { item -> PlanItemWithSubject? in
                    guard let subject = subjectMap[item.subjectId] else { return nil }
                    return PlanItemWithSubject(item: item, subject: subject)
                }
            return (day, dayItems)
        })
    }

    var totalTargetMinutes: Int {
        planItems.reduce(0) { $0 + $1.targetMinutes }
    }

    var completionRate: Double {
        guard totalTargetMinutes > 0 else { return 0 }
        let totalActual = planItems.reduce(0) { $0 + $1.actualMinutes }
        return min(Double(totalActual) / Double(totalTargetMinutes), 1)
    }

    func load() async {
        do {
            async let plansTask = app.persistence.getAllPlans()
            async let subjectsTask = app.persistence.getAllSubjects()
            let loadedPlans = try await plansTask
            plans = loadedPlans
            activePlan = loadedPlans.first(where: \.isActive)
            subjects = try await subjectsTask
            if let activePlan {
                planItems = try await app.persistence.getPlanItems(planId: activePlan.id)
                if selectedDay == nil {
                    selectedDay = StudyWeekday.allCases.first(where: { !(weeklySchedule[$0] ?? []).isEmpty }) ?? .monday
                }
            } else {
                planItems = []
                selectedDay = nil
            }
        } catch {
            app.present(error)
        }
    }

    func createPlan(name: String, startDate: Date, endDate: Date, items: [PlanItem]) {
        perform {
            let useCase = ManagePlansUseCase(repository: self.app.persistence)
            let syncedItems = items.map { item -> PlanItem in
                var value = item
                value.subjectSyncId = self.subjects.first(where: { $0.id == item.subjectId })?.syncId
                return value
            }
            try await useCase.createPlan(name: name, startDate: startDate, endDate: endDate, items: syncedItems)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func savePlanItem(_ item: PlanItem) {
        perform {
            guard item.targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            let subjectSyncId = self.subjects.first(where: { $0.id == item.subjectId })?.syncId
            let planSyncId = item.planSyncId ?? self.activePlan?.syncId
            if item.id == 0 {
                guard let activePlan = self.activePlan else {
                    throw ValidationError(message: "アクティブなプランがありません")
                }
                _ = try await self.app.persistence.insertPlanItem(
                    PlanItem(
                        planId: activePlan.id,
                        planSyncId: activePlan.syncId,
                        subjectId: item.subjectId,
                        subjectSyncId: subjectSyncId,
                        dayOfWeek: item.dayOfWeek,
                        targetMinutes: item.targetMinutes,
                        actualMinutes: item.actualMinutes,
                        timeSlot: item.timeSlot
                    )
                )
            } else {
                var updatedItem = item
                updatedItem.planSyncId = planSyncId
                updatedItem.subjectSyncId = subjectSyncId
                try await self.app.persistence.updatePlanItem(updatedItem)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deletePlanItem(_ item: PlanItem) {
        perform {
            try await self.app.persistence.deletePlanItem(item)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteActivePlan() {
        perform {
            guard let activePlan = self.activePlan else { return }
            try await self.app.persistence.deletePlan(activePlan)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}
