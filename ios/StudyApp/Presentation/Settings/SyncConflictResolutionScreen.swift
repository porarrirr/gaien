import SwiftUI

struct SyncConflictResolutionScreen: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selections: [String: SyncConflictResolutionStrategy] = [:]

    private var conflicts: [SyncConflict] {
        viewModel.app.syncRepository.pendingConflicts()
    }

    var body: some View {
        List {
            if conflicts.isEmpty {
                Text("解決が必要な競合はありません")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Section {
                    Text("端末とクラウドで同じデータが異なる内容に更新されています。残す内容を選んでください。")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                ForEach(conflicts, id: \.documentId) { conflict in
                    Section(conflict.summary) {
                        Picker("解決方法", selection: binding(for: conflict)) {
                            Text("この端末").tag(SyncConflictResolutionStrategy.keepLocal)
                            Text("クラウド").tag(SyncConflictResolutionStrategy.keepRemote)
                            Text("自動統合案").tag(SyncConflictResolutionStrategy.keepMerged)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
        .navigationTitle("同期の競合")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("適用") {
                    applyResolutions()
                }
                .disabled(conflicts.isEmpty || selections.count < conflicts.count)
            }
        }
        .onAppear {
            for conflict in conflicts where selections[conflict.documentId] == nil {
                selections[conflict.documentId] = .keepMerged
            }
        }
    }

    private func binding(for conflict: SyncConflict) -> Binding<SyncConflictResolutionStrategy> {
        Binding(
            get: { selections[conflict.documentId] ?? .keepMerged },
            set: { selections[conflict.documentId] = $0 }
        )
    }

    private func applyResolutions() {
        let resolutions = conflicts.compactMap { conflict -> SyncConflictResolution? in
            guard let strategy = selections[conflict.documentId] else { return nil }
            return SyncConflictResolution(kind: conflict.kind, syncId: conflict.syncId, strategy: strategy)
        }
        viewModel.resolveSyncConflicts(resolutions)
        dismiss()
    }
}
