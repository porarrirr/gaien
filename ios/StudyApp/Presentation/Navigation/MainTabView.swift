import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case timer
    case materials
    case calendar
    case timetable
    case reports
    case screenTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .timer:
            return "タイマー"
        case .materials:
            return "教材"
        case .timetable:
            return "時間割"
        case .calendar:
            return "カレンダー"
        case .reports:
            return "レポート"
        case .screenTime:
            return "Screen Time"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .timer:
            return "timer"
        case .materials:
            return "book.closed"
        case .timetable:
            return "tablecells"
        case .calendar:
            return "calendar"
        case .reports:
            return "chart.bar"
        case .screenTime:
            return "hourglass"
        }
    }

    @ViewBuilder
    func rootView(app: StudyAppContainer) -> some View {
        switch self {
        case .home:
            HomeScreen(app: app)
        case .timer:
            TimerScreen(app: app)
        case .materials:
            MaterialsScreen(app: app)
        case .timetable:
            TimetableScreen(app: app)
        case .calendar:
            CalendarScreen(app: app)
        case .reports:
            ReportsScreen(app: app)
        case .screenTime:
            ScreenTimeSettingsScreen(app: app)
        }
    }
}

struct MainTabView: View {
    let app: StudyAppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SceneStorage("main.selectedTab") private var selectedTab = AppTab.home.rawValue

    private var selectedAppTab: AppTab {
        AppTab(rawValue: selectedTab) ?? .home
    }

    private var selectedAppTabBinding: Binding<AppTab?> {
        Binding(
            get: { selectedAppTab },
            set: { if let tab = $0 { selectedTab = tab.rawValue } }
        )
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadNavigation
        } else {
            iPhoneTabNavigation
        }
    }

    private var iPhoneTabNavigation: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tab.rootView(app: app)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab.rawValue)
                .accessibilityLabel(tab.title)
            }
        }
    }

    private var iPadNavigation: some View {
        NavigationSplitView {
            List(selection: selectedAppTabBinding) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("StudyTrail")
        } detail: {
            NavigationStack {
                selectedAppTab.rootView(app: app)
            }
            .id(selectedAppTab)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
