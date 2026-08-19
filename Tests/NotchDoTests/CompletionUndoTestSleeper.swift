import Foundation

@MainActor
final class CompletionUndoTestSleeper {
    private var continuations: [CheckedContinuation<Void, Never>] = []

    var pendingCount: Int {
        continuations.count
    }

    func sleep(for duration: Duration) async {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeNext() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
