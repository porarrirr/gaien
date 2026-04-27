import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case timer
    case materials
    case calendar
    case reports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .timer:
            return "タイマー"
        case .materials:
            return "教材"
        case .calendar:
            return "カレンダー"
        case .reports:
            return "レポート"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .timer:
            return "timer"
        case .materials:
            return "book.closed.fill"
        case .calendar:
            return "calendar"
        case .reports:
            return "chart.bar.fill"
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
        case .calendar:
            CalendarScreen(app: app)
        case .reports:
            ReportsScreen(app: app)
        }
    }
}

struct MainTabView: View {
    let app: StudyAppContainer
    @SceneStorage("main.selectedTab") private var selectedTab = AppTab.home.rawValue

    var body: some View {
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
}
