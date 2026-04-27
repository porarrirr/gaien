import SwiftUI
import UniformTypeIdentifiers
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(VisionKit)
import VisionKit
#endif

struct MaterialsScreen: View {
    @StateObject private var viewModel: MaterialsViewModel
    @State private var materialDraft = MaterialDraft()
    @State private var editingMaterial: Material?
    @State private var progressMaterial: Material?
    @State private var isbn = ""
    @State private var isShowingScanner = false
    @State private var isShowingIsbnSearch = false
    @State private var scannerMessage: String?
    @State private var historyMaterial: Material?

    private var historyNavigationBinding: Binding<Bool> {
        Binding(
            get: { historyMaterial != nil },
            set: { isPresented in
                if !isPresented {
                    historyMaterial = nil
                }
            }
        )
    }

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: MaterialsViewModel(app: app))
    }

    var body: some View {
        Group {
            if viewModel.materials.isEmpty {
                EmptyStateView(
                    icon: "book.closed",
                    title: "教材がありません",
                    description: "教材を追加するか、ISBN から検索して登録できます。",
                    buttonTitle: viewModel.subjects.isEmpty ? "先に科目を作成" : nil,
                    onAction: viewModel.subjects.isEmpty ? nil : nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.materials) { material in
                            let subject = viewModel.subjects.first(where: { $0.id == material.subjectId })
                            let subjectName = subject?.name ?? ""
                            let subjectColor = subject?.color ?? 0x4CAF50
                            MaterialCardNew(
                                material: material,
                                subjectName: subjectName,
                                subjectColor: subjectColor,
                                canMoveUp: viewModel.materials.first?.id != material.id,
                                canMoveDown: viewModel.materials.last?.id != material.id,
                                onOpenHistory: {
                                    historyMaterial = material
                                },
                                onMoveUp: {
                                    viewModel.moveMaterial(material.id, direction: -1)
                                },
                                onMoveDown: {
                                    viewModel.moveMaterial(material.id, direction: 1)
                                },
                                onEdit: {
                                    editingMaterial = material
                                    materialDraft = MaterialDraft(material: material)
                                },
                                onDelete: {
                                    viewModel.deleteMaterial(material)
                                },
                                onUpdateProgress: {
                                    progressMaterial = material
                                }
                            )
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("教材")
        .navigationDestination(isPresented: historyNavigationBinding) {
            if let material = historyMaterial {
                MaterialHistoryScreen(app: viewModel.app, materialId: material.id)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    SubjectsScreen(app: viewModel.app)
                } label: {
                    Image(systemName: "square.grid.2x2")
                }

                Button {
                    openBarcodeScanner()
                } label: {
                    Image(systemName: "barcode.viewfinder")
                }

                Menu {
                    Button {
                        materialDraft = MaterialDraft(subjectId: viewModel.subjects.first?.id ?? 0)
                        editingMaterial = Material(id: -1, name: "", subjectId: materialDraft.subjectId, totalPages: 0)
                    } label: {
                        Label("教材を追加", systemImage: "plus")
                    }
                    Button {
                        isShowingIsbnSearch = true
                    } label: {
                        Label("ISBN検索", systemImage: "magnifyingglass")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.subjects.isEmpty {
                NavigationLink {
                    SubjectsScreen(app: viewModel.app)
                } label: {
                    Text("先に科目を作成")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding()
                .background(.bar)
            }
        }
        .sheet(isPresented: $isShowingIsbnSearch) {
            NavigationStack {
                Form {
                    Section("ISBN検索") {
                        TextField("ISBN", text: $isbn)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("ISBN検索")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { isShowingIsbnSearch = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("検索") {
                            viewModel.searchBook(isbn: isbn)
                            isShowingIsbnSearch = false
                        }
                    }
                }
            }
        }
        .sheet(item: $editingMaterial) { material in
            NavigationStack {
                MaterialEditorSheet(
                    title: material.id > 0 ? "教材を編集" : "教材を追加",
                    draft: $materialDraft,
                    subjects: viewModel.subjects,
                    onSave: {
                        viewModel.saveMaterial(
                            id: material.id > 0 ? material.id : nil,
                            name: materialDraft.name,
                            subjectId: materialDraft.subjectId,
                            totalPages: parseDraftInt(materialDraft.totalPages),
                            currentPage: material.id > 0 ? material.currentPage : 0,
                            totalProblems: parseDraftInt(materialDraft.totalProblems),
                            note: materialDraft.note
                        )
                        editingMaterial = nil
                    },
                    onCancel: {
                        editingMaterial = nil
                    }
                )
            }
        }
        .sheet(item: $progressMaterial) { material in
            NavigationStack {
                ProgressEditorSheet(
                    material: material,
                    onSave: { page in
                        viewModel.updateProgress(materialId: material.id, currentPage: page)
                        progressMaterial = nil
                    },
                    onCancel: {
                        progressMaterial = nil
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingBookResult) {
            NavigationStack {
                BookResultSheet(
                    book: viewModel.bookSearchResult,
                    subjects: viewModel.subjects,
                    fallbackSubjectId: viewModel.subjects.first?.id ?? 0,
                    onAdd: { name, subjectId, totalPages, note in
                        viewModel.saveMaterial(name: name, subjectId: subjectId, totalPages: totalPages, note: note)
                        viewModel.clearSearchResult()
                    },
                    onClose: {
                        viewModel.clearSearchResult()
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerSheet(
                onScanned: { code in
                    isbn = code
                    viewModel.app.logger.log(category: .barcode, message: "Barcode scanned", details: "isbn=\(code)")
                    viewModel.searchBook(isbn: code)
                    isShowingScanner = false
                },
                onFailure: { message in
                    scannerMessage = message
                    isShowingScanner = false
                },
                logger: viewModel.app.logger
            )
        }
        .alert("バーコード読み取り", isPresented: Binding(get: { scannerMessage != nil }, set: { if !$0 { scannerMessage = nil } })) {
            Button("OK", role: .cancel) {
                scannerMessage = nil
            }
        } message: {
            Text(scannerMessage ?? "")
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
            if materialDraft.subjectId == 0 {
                materialDraft.subjectId = viewModel.subjects.first?.id ?? 0
            }
        }
    }

    private func openBarcodeScanner() {
        #if canImport(AVFoundation)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            viewModel.app.logger.log(category: .barcode, message: "Camera permission already authorized")
            isShowingScanner = true
        case .notDetermined:
            viewModel.app.logger.log(category: .barcode, message: "Requesting camera permission")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.viewModel.app.logger.log(category: .barcode, message: "Camera permission granted")
                        self.isShowingScanner = true
                    } else {
                        self.viewModel.app.logger.log(category: .barcode, level: .warning, message: "Camera permission denied by user")
                        self.scannerMessage = "カメラへのアクセスが許可されていません。設定アプリでカメラを許可してください。"
                    }
                }
            }
        case .denied, .restricted:
            viewModel.app.logger.log(category: .barcode, level: .warning, message: "Camera permission unavailable", details: "status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
            scannerMessage = "カメラへのアクセスが許可されていません。設定アプリでカメラを許可してください。"
        @unknown default:
            viewModel.app.logger.log(category: .barcode, level: .warning, message: "Unknown camera authorization status")
            scannerMessage = "この端末ではバーコード読み取りを開始できませんでした。"
        }
        #else
        viewModel.app.logger.log(category: .barcode, level: .warning, message: "AVFoundation unavailable for barcode scanner")
        scannerMessage = "この端末ではバーコード読み取りを利用できません。"
        #endif
    }
}

private struct MaterialCardNew: View {
    let material: Material
    let subjectName: String
    let subjectColor: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onOpenHistory: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onUpdateProgress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                // Subject color accent
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: subjectColor))
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(material.name)
                        .font(.headline)
                    Text(subjectName)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Menu {
                    Button(action: onMoveUp) {
                        Label("上へ移動", systemImage: "arrow.up")
                    }
                    .disabled(!canMoveUp)
                    Button(action: onMoveDown) {
                        Label("下へ移動", systemImage: "arrow.down")
                    }
                    .disabled(!canMoveDown)
                    Button { onEdit() } label: { Label("編集", systemImage: "pencil") }
                    if material.totalPages > 0 {
                        Button { onUpdateProgress() } label: { Label("進捗を更新", systemImage: "chart.line.uptrend.xyaxis") }
                    }
                    Button(role: .destructive) { onDelete() } label: { Label("削除", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }

            if material.totalPages > 0 {
                AnimatedProgressBar(
                    value: Double(material.currentPage),
                    total: Double(material.totalPages),
                    height: 8,
                    barColor: Color(hex: subjectColor)
                )
                HStack {
                    Text("\(material.currentPage)/\(material.totalPages)ページ")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("\(material.progressPercent)%")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: subjectColor))
                }
            }

            if material.totalProblems > 0 {
                Text("全\(material.totalProblems)問")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let note = material.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenHistory)
    }
}

private struct MaterialHistoryScreen: View {
    @StateObject private var viewModel: MaterialHistoryViewModel
    @State private var selectedTab: MaterialDetailTab = .history

    init(app: StudyAppContainer, materialId: Int64) {
        _viewModel = StateObject(wrappedValue: MaterialHistoryViewModel(app: app, materialId: materialId))
    }

    var body: some View {
        Group {
            if let material = viewModel.material {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        MaterialHistorySummaryCard(
                            material: material,
                            subject: viewModel.subject,
                            totalMinutes: viewModel.totalMinutes,
                            sessionCount: viewModel.sessions.count,
                            latestStudyDate: viewModel.latestStudyDate
                        )
                        .padding(.horizontal, AppSpacing.md)

                        Picker("表示", selection: $selectedTab) {
                            ForEach(MaterialDetailTab.allCases) { tab in
                                Label(tab.title, systemImage: tab.systemImage).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppSpacing.md)

                        if selectedTab == .history {
                            MaterialHistoryCalendarView(
                                displayedMonth: viewModel.displayedMonth,
                                selectedDate: viewModel.selectedDate,
                                studyMinutesByDay: viewModel.studyMinutesByDay,
                                onPrevious: viewModel.previousMonth,
                                onNext: viewModel.nextMonth,
                                onSelectDate: viewModel.selectDate
                            )
                            .padding(.horizontal, AppSpacing.md)

                            selectedDaySection
                                .padding(.horizontal, AppSpacing.md)
                        } else {
                            MaterialProblemProgressCard(
                                totalProblems: material.totalProblems,
                                materialRecords: material.problemRecords,
                                sessions: viewModel.sessions,
                                onRecordsChange: { records in
                                    viewModel.updateProblemRecords(records)
                                }
                            )
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            } else {
                EmptyStateView(
                    icon: "book.closed",
                    title: "教材が見つかりません",
                    description: "教材一覧からもう一度選択してください。"
                )
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle(viewModel.material?.name ?? "教材の履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: selectedDateTitle, icon: "calendar")
            reviewJumpControls
            Text("合計 \(Goal.format(minutes: viewModel.selectedDateMinutes)) ・ \(viewModel.selectedDateSessions.count)回")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            if viewModel.selectedDateSessions.isEmpty {
                Text("この日の記録はありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
                    .cardStyle()
            } else {
                ForEach(viewModel.selectedDateSessions) { session in
                    MaterialHistorySessionCard(session: session)
                }
            }
        }
    }

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: viewModel.selectedDate)
    }

    private var reviewJumpControls: some View {
        HStack(spacing: AppSpacing.sm) {
            Button("前日") {
                viewModel.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            }
            Button("1週間前") {
                viewModel.selectDate(Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
            }
            Button("1か月前") {
                viewModel.selectDate(Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date())
            }
        }
        .font(.caption.bold())
        .buttonStyle(.bordered)
    }
}

private enum MaterialDetailTab: String, CaseIterable, Identifiable {
    case history
    case problems

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "履歴"
        case .problems: return "問題集"
        }
    }

    var systemImage: String {
        switch self {
        case .history: return "calendar"
        case .problems: return "square.grid.3x3.fill"
        }
    }
}

private struct MaterialHistorySummaryCard: View {
    let material: Material
    let subject: Subject?
    let totalMinutes: Int
    let sessionCount: Int
    let latestStudyDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(material.name)
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Text(subject?.name ?? "科目未設定")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if material.totalPages > 0 {
                AnimatedProgressBar(
                    value: Double(material.currentPage),
                    total: Double(material.totalPages),
                    height: 8
                )
                HStack {
                    Text("\(material.currentPage)/\(material.totalPages)ページ")
                    Spacer()
                    Text("\(material.progressPercent)%")
                        .fontWeight(.bold)
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            if material.totalProblems > 0 {
                Text("全問題数: \(material.totalProblems)問")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: AppSpacing.sm) {
                MaterialHistoryMetric(label: "累計", value: Goal.format(minutes: totalMinutes))
                MaterialHistoryMetric(label: "記録", value: "\(sessionCount)回")
                MaterialHistoryMetric(label: "最終", value: latestStudyDate.map(shortDate) ?? "なし")
            }
        }
        .cardStyle()
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

private struct MaterialHistoryMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MaterialProblemProgressCard: View {
    let totalProblems: Int
    let materialRecords: [ProblemSessionRecord]
    let sessions: [StudySession]
    let onRecordsChange: ([ProblemSessionRecord]) -> Void

    @State private var editingNumber: Int?
    @State private var editingStatus: MaterialProblemStatus = .untouched
    @State private var detailText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "問題集の進捗", icon: "square.grid.3x3.fill")

            if totalProblems <= 0 {
                EmptyStateView(
                    icon: "number.square",
                    title: "全問題数が未設定です",
                    description: "教材編集から問題数を設定すると、ここに進捗が表示されます。"
                )
                .padding(.vertical, AppSpacing.sm)
            } else {
                HStack(spacing: AppSpacing.sm) {
                    MaterialHistoryMetric(label: "実施", value: "\(doneNumbers.count)/\(totalProblems)")
                    MaterialHistoryMetric(label: "誤答あり", value: "\(wrongNumbers.count)")
                    MaterialHistoryMetric(label: "未実施", value: "\(max(totalProblems - doneNumbers.count, 0))")
                }

                HStack(spacing: AppSpacing.sm) {
                    MaterialProblemLegendItem(label: "未着手", color: Color.secondary.opacity(0.12), textColor: AppColors.textSecondary)
                    MaterialProblemLegendItem(label: "正解", color: AppColors.success.opacity(0.18), textColor: AppColors.success)
                    MaterialProblemLegendItem(label: "間違い", color: AppColors.danger.opacity(0.18), textColor: AppColors.danger)
                }

                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(1...totalProblems, id: \.self) { number in
                        MaterialProblemStatusTile(
                            number: number,
                            status: status(for: number),
                            hasDetail: detail(for: number) != nil,
                            onTap: {
                                toggleCorrect(number)
                            },
                            onLongPress: {
                                openEditor(for: number)
                            }
                        )
                    }
                }

                if !wrongNumbers.isEmpty {
                    Text("誤答: \(wrongNumbers.sorted().prefix(30).map(String.init).joined(separator: ", "))\(wrongNumbers.count > 30 ? " ..." : "")")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .cardStyle()
        .sheet(item: Binding(
            get: { editingNumber.map(MaterialProblemEditTarget.init(number:)) },
            set: { if $0 == nil { editingNumber = nil } }
        )) { target in
            NavigationStack {
                Form {
                    Picker("状態", selection: $editingStatus) {
                        Text("未着手").tag(MaterialProblemStatus.untouched)
                        Text("正解").tag(MaterialProblemStatus.correct)
                        Text("間違い").tag(MaterialProblemStatus.wrong)
                    }
                    TextField("大問・小問メモ", text: $detailText, axis: .vertical)
                }
                .navigationTitle("\(target.number)問目")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { editingNumber = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            saveEditedRecord(number: target.number)
                            editingNumber = nil
                        }
                    }
                }
            }
        }
    }

    private var tileColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 48), spacing: 10), count: 5)
    }

    private var doneNumbers: Set<Int> {
        Set(materialRecords.map(\.number)).union(Set(sessions.flatMap { session in
            if !session.problemRecords.isEmpty {
                return session.problemRecords.map(\.number)
            }
            guard let start = session.problemStart, let end = session.problemEnd, end >= start else { return [] }
            return Array(start...end)
        }))
    }

    private var wrongNumbers: Set<Int> {
        Set(materialRecords.filter(\.isWrong).map(\.number)).union(Set(sessions.flatMap { session in
            session.problemRecords.filter(\.isWrong).map(\.number)
        }))
    }

    private func status(for number: Int) -> MaterialProblemStatus {
        if wrongNumbers.contains(number) {
            return .wrong
        }
        if doneNumbers.contains(number) {
            return .correct
        }
        return .untouched
    }

    private func detail(for number: Int) -> String? {
        materialRecords.first(where: { $0.number == number })?.detail?.nilIfBlank
            ?? sessions
                .flatMap { $0.problemRecords }
                .first(where: { $0.number == number })?
                .detail?
                .nilIfBlank
    }

    private func toggleCorrect(_ number: Int) {
        var nextRecords = materialRecords
        if let index = nextRecords.firstIndex(where: { $0.number == number }) {
            if nextRecords[index].isWrong {
                nextRecords[index].isWrong = false
            } else {
                nextRecords.remove(at: index)
            }
        } else {
            nextRecords.append(ProblemSessionRecord(number: number, isWrong: false))
        }
        onRecordsChange(nextRecords.sorted { $0.number < $1.number })
    }

    private func openEditor(for number: Int) {
        editingNumber = number
        editingStatus = status(for: number)
        detailText = detail(for: number) ?? ""
    }

    private func saveEditedRecord(number: Int) {
        var nextRecords = materialRecords
        nextRecords.removeAll { $0.number == number }
        guard editingStatus != .untouched else {
            onRecordsChange(nextRecords.sorted { $0.number < $1.number })
            return
        }
        nextRecords.append(
            ProblemSessionRecord(
                number: number,
                isWrong: editingStatus == .wrong,
                detail: detailText.nilIfBlank
            )
        )
        onRecordsChange(nextRecords.sorted { $0.number < $1.number })
    }
}

private enum MaterialProblemStatus: Hashable {
    case untouched
    case correct
    case wrong
}

private struct MaterialProblemEditTarget: Identifiable {
    let number: Int
    var id: Int { number }
}

private struct MaterialProblemLegendItem: View {
    let label: String
    let color: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(textColor.opacity(0.45), lineWidth: 1)
                )
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MaterialProblemStatusTile: View {
    let number: Int
    let status: MaterialProblemStatus
    let hasDetail: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text("\(number)")
                .font(.callout.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if hasDetail {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .aspectRatio(1, contentMode: .fit)
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("タップで正解を切り替え、長押しで状態とメモを編集")
    }

    private var background: Color {
        switch status {
        case .untouched:
            return Color.secondary.opacity(0.08)
        case .correct:
            return AppColors.success.opacity(0.18)
        case .wrong:
            return AppColors.danger.opacity(0.18)
        }
    }

    private var foreground: Color {
        switch status {
        case .untouched:
            return AppColors.textSecondary
        case .correct:
            return AppColors.success
        case .wrong:
            return AppColors.danger
        }
    }

    private var border: Color {
        switch status {
        case .untouched:
            return Color.secondary.opacity(0.15)
        case .correct:
            return AppColors.success.opacity(0.45)
        case .wrong:
            return AppColors.danger.opacity(0.55)
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case .untouched:
            return "\(number)問目 未着手"
        case .correct:
            return "\(number)問目 正解"
        case .wrong:
            return "\(number)問目 間違い"
        }
    }
}

private struct MaterialHistoryCalendarView: View {
    let displayedMonth: Date
    let selectedDate: Date
    let studyMinutesByDay: [Int: Int]
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarCells.indices, id: \.self) { index in
                    if let date = calendarCells[index] {
                        let day = Calendar.current.component(.day, from: date)
                        MaterialHistoryDayCell(
                            day: day,
                            minutes: studyMinutesByDay[day] ?? 0,
                            maxMinutes: studyMinutesByDay.values.max() ?? 0,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        ) {
                            onSelectDate(date)
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: displayedMonth)
    }

    private var calendarCells: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = interval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        let days = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        var cells = Array<Date?>(repeating: nil, count: firstWeekday)
        for dayOffset in 0..<days {
            cells.append(calendar.date(byAdding: .day, value: dayOffset, to: firstDay))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }
}

private struct MaterialHistoryDayCell: View {
    let day: Int
    let minutes: Int
    let maxMinutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.caption.bold())
                if minutes > 0 {
                    Text("\(minutes)分")
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(isSelected || heatLevel >= 3 ? .white : AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var heatLevel: Int {
        guard minutes > 0, maxMinutes > 0 else { return 0 }
        let ratio = Double(minutes) / Double(maxMinutes)
        if ratio >= 0.75 { return 4 }
        if ratio >= 0.5 { return 3 }
        if ratio >= 0.25 { return 2 }
        return 1
    }

    private var backgroundColor: Color {
        if isSelected { return .accentColor }
        switch heatLevel {
        case 1: return Color(hex: 0xDDEEDB)
        case 2: return Color(hex: 0x9BD58A)
        case 3: return Color(hex: 0x5AAD5A)
        case 4: return Color(hex: 0x2E7D32)
        default: return Color.secondary.opacity(0.08)
        }
    }
}

private struct MaterialHistorySessionCard: View {
    let session: StudySession

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(intervalText)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(session.durationJapaneseText)
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
                Spacer()
            }

            Divider()

            Text(session.note?.nilIfBlank ?? "メモはありません")
                .font(.subheadline)
                .foregroundStyle(session.note?.nilIfBlank == nil ? AppColors.textSecondary : AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session.problemRangeText != nil || session.wrongProblemCount != nil {
                HStack {
                    Label(session.problemRangeText ?? "範囲未入力", systemImage: "list.number")
                    Spacer()
                    Text("誤答 \(session.effectiveWrongProblemCount ?? 0)")
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            }
            if !session.problemRecords.filter({ $0.detail?.nilIfBlank != nil }).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.problemRecords.filter { $0.detail?.nilIfBlank != nil }) { record in
                        Text("\(record.number)問目: \(record.detail ?? "")")
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
            }
        }
        .cardStyle()
    }

    private var intervalText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return session.effectiveIntervals.map { interval in
            "\(formatter.string(from: Date(epochMilliseconds: interval.startTime))) - \(formatter.string(from: Date(epochMilliseconds: interval.endTime)))"
        }
        .joined(separator: "\n")
    }
}

private struct MaterialEditorSheet: View {
    let title: String
    @Binding var draft: MaterialDraft
    let subjects: [Subject]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            if subjects.isEmpty {
                Text("先に科目を作成してください")
            } else {
                TextField("教材名", text: $draft.name)
                Picker("科目", selection: $draft.subjectId) {
                    ForEach(subjects) { subject in
                        Text(subject.name).tag(subject.id)
                    }
                }
                TextField("総ページ数", text: $draft.totalPages)
                    .keyboardType(.numberPad)
                TextField("全問題数", text: $draft.totalProblems)
                    .keyboardType(.numberPad)
                TextField("メモ", text: $draft.note, axis: .vertical)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
                    .disabled(subjects.isEmpty)
            }
        }
    }
}

private struct ProgressEditorSheet: View {
    let material: Material
    let onSave: (Int) -> Void
    let onCancel: () -> Void
    @State private var currentPage: String

    init(material: Material, onSave: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.material = material
        self.onSave = onSave
        self.onCancel = onCancel
        _currentPage = State(initialValue: "\(material.currentPage)")
    }

    var body: some View {
        Form {
            Section {
                Text(material.name)
                    .font(.headline)
            }
            Section("進捗") {
                TextField("現在ページ", text: $currentPage)
                    .keyboardType(.numberPad)
                if material.totalPages > 0 {
                    Text("総ページ数: \(material.totalPages)")
                        .foregroundStyle(.secondary)
                    if let page = Int(currentPage), material.totalPages > 0 {
                        AnimatedProgressBar(
                            value: Double(page),
                            total: Double(material.totalPages),
                            height: 8
                        )
                    }
                }
            }
        }
        .navigationTitle("進捗を更新")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(Int(currentPage) ?? material.currentPage)
                }
            }
        }
    }
}

private struct BookResultSheet: View {
    let book: BookInfo?
    let subjects: [Subject]
    let fallbackSubjectId: Int64
    let onAdd: (String, Int64, Int, String?) -> Void
    let onClose: () -> Void
    @State private var selectedSubjectId: Int64

    init(
        book: BookInfo?,
        subjects: [Subject],
        fallbackSubjectId: Int64,
        onAdd: @escaping (String, Int64, Int, String?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.book = book
        self.subjects = subjects
        self.fallbackSubjectId = fallbackSubjectId
        self.onAdd = onAdd
        self.onClose = onClose
        _selectedSubjectId = State(initialValue: fallbackSubjectId)
    }

    var body: some View {
        Form {
            if let book {
                Text(book.title).font(.headline)
                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                }
                Picker("科目", selection: $selectedSubjectId) {
                    ForEach(subjects) { subject in
                        Text(subject.name).tag(subject.id)
                    }
                }
                if let pages = book.pageCount {
                    Text("ページ数: \(pages)")
                }
            } else {
                Text("書籍が見つかりませんでした")
            }
        }
        .navigationTitle("検索結果")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる", action: onClose)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("追加") {
                    guard let book else { return }
                    let noteParts = [book.publisher, book.publishedDate].compactMap { $0 }
                    onAdd(
                        book.title,
                        selectedSubjectId,
                        book.pageCount ?? 0,
                        noteParts.isEmpty ? nil : noteParts.joined(separator: " / ")
                    )
                }
                .disabled(book == nil || subjects.isEmpty)
            }
        }
    }
}

private struct MaterialDraft {
    var name = ""
    var subjectId: Int64 = 0
    var totalPages = ""
    var totalProblems = ""
    var note = ""

    init(subjectId: Int64 = 0) {
        self.subjectId = subjectId
    }

    init(material: Material) {
        name = material.name
        subjectId = material.subjectId
        totalPages = "\(material.totalPages)"
        totalProblems = material.totalProblems == 0 ? "" : "\(material.totalProblems)"
        note = material.note ?? ""
    }
}

private func parseDraftInt(_ value: String) -> Int {
    let normalized = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
    return Int(normalized.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}

private struct BarcodeScannerSheet: View {
    let onScanned: (String) -> Void
    let onFailure: (String) -> Void
    let logger: AppLogger
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BarcodeScannerView(onScanned: { code in
                onScanned(code)
                dismiss()
            }, onFailure: { message in
                logger.log(category: .barcode, level: .warning, message: "Scanner reported failure", details: message)
                onFailure(message)
                dismiss()
            }, logger: logger)
            .navigationTitle("バーコード")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct BarcodeScannerView: View {
    let onScanned: (String) -> Void
    let onFailure: (String) -> Void
    let logger: AppLogger

    var body: some View {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *), DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            ScannerRepresentable(onScanned: onScanned, onFailure: onFailure, logger: logger)
        } else {
            scannerUnavailableState
                .onAppear {
                    logger.log(category: .barcode, level: .warning, message: "VisionKit scanner unavailable", details: "supported=\(DataScannerViewController.isSupported) available=\(DataScannerViewController.isAvailable)")
                }
        }
        #else
        scannerUnavailableState
            .onAppear {
                logger.log(category: .barcode, level: .warning, message: "VisionKit unavailable for barcode scanner")
            }
        #endif
    }

    private var scannerUnavailableState: some View {
        EmptyStateView(
            icon: "barcode.viewfinder",
            title: "バーコードを利用できません",
            description: "この端末ではバーコードスキャンを利用できません。"
        )
    }
}

#if canImport(VisionKit)
@available(iOS 16.0, *)
private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onFailure: (String) -> Void
    let logger: AppLogger

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onFailure: onFailure, logger: logger)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        context.coordinator.attach(controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.attach(uiViewController)
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        coordinator.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScanned: (String) -> Void
        let onFailure: (String) -> Void
        let logger: AppLogger
        weak var controller: DataScannerViewController?
        private var hasCompletedScan = false
        private var hasStartedScanning = false

        init(onScanned: @escaping (String) -> Void, onFailure: @escaping (String) -> Void, logger: AppLogger) {
            self.onScanned = onScanned
            self.onFailure = onFailure
            self.logger = logger
        }

        func attach(_ controller: DataScannerViewController) {
            self.controller = controller
            guard !hasStartedScanning else { return }
            do {
                try controller.startScanning()
                hasStartedScanning = true
                logger.log(category: .barcode, message: "Barcode scanner started")
            } catch {
                logger.log(category: .barcode, level: .error, message: "Failed to start barcode scanner", error: error)
                onFailure("バーコードスキャナの起動に失敗しました。")
            }
        }

        func stopScanning() {
            guard hasStartedScanning else { return }
            controller?.stopScanning()
            hasStartedScanning = false
            logger.log(category: .barcode, message: "Barcode scanner stopped")
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasCompletedScan else { return }
            guard let first = addedItems.first else { return }
            if case .barcode(let barcode) = first, let payload = barcode.payloadStringValue {
                hasCompletedScan = true
                logger.log(category: .barcode, message: "Recognized barcode payload", details: "payload=\(payload)")
                stopScanning()
                onScanned(payload)
            }
        }
    }
}
#endif
