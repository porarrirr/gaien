import SwiftUI
import UniformTypeIdentifiers
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

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: MaterialsViewModel(app: app))
    }

    var body: some View {
        Group {
            if viewModel.materials.isEmpty {
                EmptyMaterialsState()
            } else {
                List {
                    ForEach(viewModel.materials) { material in
                        let subjectName = viewModel.subjects.first(where: { $0.id == material.subjectId })?.name ?? ""
                        MaterialCard(
                            material: material,
                            subjectName: subjectName,
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
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("教材")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    SubjectsScreen(app: viewModel.app)
                } label: {
                    Image(systemName: "square.grid.2x2")
                }

                Button {
                    isShowingScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                }

                Button {
                    materialDraft = MaterialDraft(subjectId: viewModel.subjects.first?.id ?? 0)
                    editingMaterial = Material(id: -1, name: "", subjectId: materialDraft.subjectId, totalPages: 0)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.subjects.isEmpty {
                IsbnSearchBar(
                    isbn: $isbn,
                    onSearch: { viewModel.searchBook(isbn: isbn) }
                )
                .padding()
                .background(.bar)
            } else {
                NavigationLink {
                    SubjectsScreen(app: viewModel.app)
                } label: {
                    Text("先に科目を作成")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
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
                            totalPages: Int(materialDraft.totalPages) ?? 0,
                            currentPage: material.id > 0 ? material.currentPage : 0,
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
            BarcodeScannerSheet { code in
                isbn = code
                viewModel.searchBook(isbn: code)
                isShowingScanner = false
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
            if materialDraft.subjectId == 0 {
                materialDraft.subjectId = viewModel.subjects.first?.id ?? 0
            }
        }
    }
}

private struct MaterialCard: View {
    let material: Material
    let subjectName: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onUpdateProgress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.name)
                        .font(.headline)
                    Text(subjectName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }

            if material.totalPages > 0 {
                ProgressView(value: material.progress)
                HStack {
                    Text("\(material.currentPage)/\(material.totalPages)ページ")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(material.progressPercent)%")
                        .foregroundStyle(.tint)
                }
                Button("進捗を更新", action: onUpdateProgress)
                    .buttonStyle(.bordered)
            }

            if let note = material.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyMaterialsState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("教材がありません")
                .font(.title3.bold())
            Text("教材を追加するか、ISBN から検索して登録できます。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct IsbnSearchBar: View {
    @Binding var isbn: String
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ISBN検索")
                .font(.headline)
            HStack {
                TextField("ISBN", text: $isbn)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("検索", action: onSearch)
                    .buttonStyle(.borderedProminent)
            }
        }
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
            Text(material.name)
            TextField("現在ページ", text: $currentPage)
                .keyboardType(.numberPad)
            if material.totalPages > 0 {
                Text("総ページ数: \(material.totalPages)")
                    .foregroundStyle(.secondary)
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
    var note = ""

    init(subjectId: Int64 = 0) {
        self.subjectId = subjectId
    }

    init(material: Material) {
        name = material.name
        subjectId = material.subjectId
        totalPages = "\(material.totalPages)"
        note = material.note ?? ""
    }
}

private struct BarcodeScannerSheet: View {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BarcodeScannerView { code in
                onScanned(code)
                dismiss()
            }
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

    var body: some View {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *), DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            ScannerRepresentable(onScanned: onScanned)
        } else {
            scannerUnavailableState
        }
        #else
        scannerUnavailableState
        #endif
    }

    private var scannerUnavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 40))
            Text("バーコードを利用できません")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if canImport(VisionKit)
@available(iOS 16.0, *)
private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
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
        do {
            try controller.startScanning()
        } catch {
            print("[StudyApp] Failed to start barcode scanner: \(error.localizedDescription)")
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScanned: (String) -> Void

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let first = addedItems.first else { return }
            if case .barcode(let barcode) = first, let payload = barcode.payloadStringValue {
                onScanned(payload)
            }
        }
    }
}
#endif
