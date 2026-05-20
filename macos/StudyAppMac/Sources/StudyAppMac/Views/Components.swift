import SwiftUI

struct HeaderView<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            actions
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let progress: Double?

    var body: some View {
        SectionCard(title: title) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                }
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

struct SessionRow: View {
    @Bindable var store: StudyStore
    let session: StudySessionRecord

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(store.subject(for: session.subjectID)?.color ?? .gray)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.subject(for: session.subjectID)?.name ?? "Unknown Subject")
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(session.startedAt, style: .date)
                    Text(session.durationMinutes.studyDurationText)
                    if let material = store.material(for: session.materialID) {
                        Text(material.title)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Label("\(session.rating)", systemImage: "star.fill")
                .foregroundStyle(.yellow)
                .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 7)
    }
}
