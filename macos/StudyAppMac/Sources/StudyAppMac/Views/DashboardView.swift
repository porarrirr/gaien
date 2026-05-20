import SwiftUI

struct DashboardView: View {
    @Bindable var store: StudyStore
    let showSessionSheet: () -> Void

    private var dailyProgress: Double {
        guard let target = store.activeDailyGoal?.targetMinutes, target > 0 else { return 0 }
        return min(Double(store.todayMinutes) / Double(target), 1)
    }

    private var weeklyProgress: Double {
        guard let target = store.activeWeeklyGoal?.targetMinutes, target > 0 else { return 0 }
        return min(Double(store.weekMinutes) / Double(target), 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderView(
                    title: "Dashboard",
                    subtitle: "Track focus time, recent sessions, and goal progress from one desktop workspace."
                ) {
                    Button(action: showSessionSheet) {
                        Label("Add Session", systemImage: "plus")
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    MetricCard(title: "Today", value: store.todayMinutes.studyDurationText, systemImage: "sun.max", progress: dailyProgress)
                    MetricCard(title: "This Week", value: store.weekMinutes.studyDurationText, systemImage: "calendar", progress: weeklyProgress)
                    MetricCard(title: "Subjects", value: "\(store.subjects.count)", systemImage: "books.vertical", progress: nil)
                    MetricCard(title: "Sessions", value: "\(store.sessions.count)", systemImage: "clock.arrow.circlepath", progress: nil)
                }

                TimerPanel(store: store)

                SectionCard(title: "Recent Sessions") {
                    if store.recentSessions.isEmpty {
                        EmptyStateView(title: "No sessions yet", systemImage: "clock.badge.questionmark")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(store.recentSessions.prefix(6)) { session in
                                SessionRow(store: store, session: session)
                                if session.id != store.recentSessions.prefix(6).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }
}

struct TimerPanel: View {
    @Bindable var store: StudyStore
    @State private var tick = Date()

    var body: some View {
        SectionCard(title: "Focus Timer") {
            HStack(spacing: 16) {
                Image(systemName: store.timer.isRunning ? "timer" : "timer.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(store.timer.isRunning ? .green : .secondary)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.timer.isRunning ? store.timer.elapsed.timerText : "00:00")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(timerSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.timer.isRunning ? store.stopTimer() : store.startTimer()
                } label: {
                    Label(store.timer.isRunning ? "Stop" : "Start", systemImage: store.timer.isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            tick = date
        }
    }

    private var timerSubtitle: String {
        _ = tick
        guard store.timer.isRunning else { return "Ready for your next study block" }
        return store.subject(for: store.timer.subjectID)?.name ?? "Studying"
    }
}
