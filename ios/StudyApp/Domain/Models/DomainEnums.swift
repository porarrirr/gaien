import Foundation

enum SubjectIcon: String, CaseIterable, Codable, Identifiable, Hashable {
    case book = "BOOK"
    case calculator = "CALCULATOR"
    case flask = "FLASK"
    case globe = "GLOBE"
    case palette = "PALETTE"
    case music = "MUSIC"
    case code = "CODE"
    case atom = "ATOM"
    case dna = "DNA"
    case brain = "BRAIN"
    case language = "LANGUAGE"
    case history = "HISTORY"
    case other = "OTHER"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .book: return "book.closed.fill"
        case .calculator: return "function"
        case .flask: return "testtube.2"
        case .globe: return "globe.asia.australia.fill"
        case .palette: return "paintpalette.fill"
        case .music: return "music.note"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .atom: return "atom"
        case .dna: return "cross.case.fill"
        case .brain: return "brain.head.profile"
        case .language: return "character.book.closed.fill"
        case .history: return "clock.arrow.circlepath"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

enum GoalType: String, CaseIterable, Codable, Identifiable, Hashable {
    case daily = "DAILY"
    case weekly = "WEEKLY"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "1日の目標"
        case .weekly: return "週間目標"
        }
    }
}

enum StudyWeekday: String, CaseIterable, Codable, Identifiable, Hashable {
    case monday = "MONDAY"
    case tuesday = "TUESDAY"
    case wednesday = "WEDNESDAY"
    case thursday = "THURSDAY"
    case friday = "FRIDAY"
    case saturday = "SATURDAY"
    case sunday = "SUNDAY"

    var id: String { rawValue }

    var japaneseShortTitle: String {
        switch self {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }

    var japaneseTitle: String {
        japaneseShortTitle + "曜日"
    }

    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static func from(calendarWeekday: Int) -> StudyWeekday {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
        }
    }
}

enum ThemeMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "ライト"
        case .dark: return "ダーク"
        case .system: return "システム"
        }
    }

}

enum ColorTheme: String, CaseIterable, Codable, Identifiable, Hashable {
    case green
    case blue
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green: return "グリーン"
        case .blue: return "ブルー"
        case .orange: return "オレンジ"
        }
    }

    var hex: Int {
        switch self {
        case .green: return 0x2E9D45
        case .blue: return 0x1E88E5
        case .orange: return 0xF59E0B
        }
    }

    var accentHex: Int {
        switch self {
        case .green: return 0x1E88E5
        case .blue: return 0x2E9D45
        case .orange: return 0x1E88E5
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }
}

enum LiveActivityDisplayPreset: String, CaseIterable, Codable, Identifiable, Hashable {
    case standard
    case focus
    case progress
    case subjectDetail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "標準"
        case .focus: return "集中"
        case .progress: return "進捗"
        case .subjectDetail: return "科目詳細"
        }
    }

    var settingsDescription: String {
        switch self {
        case .standard: return "経過時間を大きく表示し、科目と教材を並べます。"
        case .focus: return "経過時間を最優先で表示し、補助情報を最小にします。"
        case .progress: return "経過時間に加えて今日の記録時間と目標を表示します。"
        case .subjectDetail: return "科目名を主役にして教材と開始時刻を表示します。"
        }
    }
}

enum TimerVisualMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case auto
    case morning
    case day
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "自動"
        case .morning: return "朝"
        case .day: return "昼"
        case .night: return "夜"
        }
    }

    var settingsDescription: String {
        switch self {
        case .auto: return "現在地の天気と日の出・日の入りに合わせます。"
        case .morning: return "朝の明るい青緑の背景で固定します。"
        case .day: return "昼のクリアな背景で固定します。"
        case .night: return "夜の集中しやすい暗い背景で固定します。"
        }
    }
}

enum LandscapeTimerDisplayPreset: String, CaseIterable, Codable, Identifiable, Hashable {
    case problemProgress
    case clockOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .problemProgress: return "問題集つき"
        case .clockOnly: return "時計のみ"
        }
    }

    var settingsDescription: String {
        switch self {
        case .problemProgress: return "横向き時に問題番号タイルと時計を並べて表示します。"
        case .clockOnly: return "横向き時は時計と小さい操作ボタンだけを表示します。"
        }
    }
}
