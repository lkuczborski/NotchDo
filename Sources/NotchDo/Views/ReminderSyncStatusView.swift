import SwiftUI

struct ReminderSyncStatusView: View {
    let syncState: ReminderSyncState
    let lastSyncedAt: Date?
    let isReadOnly: Bool
    let formatter: ReminderSyncStatusFormatter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isVisible {
            HStack(spacing: 5) {
                if isReadOnly {
                    Image(systemName: "lock.fill")
                        .accessibilityHidden(true)
                    Text("Read only")
                }

                if isReadOnly, syncText != nil {
                    Text("·")
                        .accessibilityHidden(true)
                }

                syncIndicator

                if let syncText {
                    Text(syncText)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var syncIndicator: some View {
        switch syncState {
        case .syncing:
            if reduceMotion {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.48))
                    .scaleEffect(0.65)
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)
            }
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)
        case .idle, .synced:
            EmptyView()
        }
    }

    private var syncText: String? {
        switch syncState {
        case .syncing:
            return "Updating…"
        case .failed:
            return "Update failed"
        case .idle, .synced:
            return lastSyncedAt.map(formatter.updatedText(for:))
        }
    }

    private var isVisible: Bool {
        isReadOnly || syncText != nil
    }

    private var statusColor: Color {
        if case .failed = syncState {
            return .orange.opacity(0.88)
        }
        return .white.opacity(0.42)
    }
}
