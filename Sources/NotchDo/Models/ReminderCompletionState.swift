import Foundation
import Observation

/// Feedback and duplicate-tap protection for one completion operation.
@MainActor
@Observable
final class ReminderCompletionState {
    private(set) var isCompleting = false

    @discardableResult
    func complete(
        isEditable: Bool,
        prepare: () -> Void = {},
        sleep: () async throws -> Void = {
            try await Task.sleep(for: .milliseconds(160))
        },
        action: () async -> Bool
    ) async -> Bool {
        guard isEditable, !isCompleting else { return false }
        isCompleting = true
        // List can retain the same row through removal and Undo. Always release
        // operation state, including after success, failure, and cancellation.
        defer { isCompleting = false }
        prepare()
        do {
            try await sleep()
        } catch {
            return false
        }
        guard !Task.isCancelled else { return false }
        return await action()
    }
}
