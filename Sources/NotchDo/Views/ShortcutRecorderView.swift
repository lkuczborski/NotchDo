import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    let store: GlobalShortcutStore
    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Quick capture shortcut")
                Spacer()
                Button(isRecording ? "Type shortcut…" : store.shortcut.displayName) {
                    beginRecording()
                }
                .frame(minWidth: 118)
                .accessibilityLabel(
                    isRecording
                        ? "Type a new quick capture shortcut"
                        : "Quick capture shortcut, \(store.shortcut.displayName)"
                )
            }

            Text("Opens Quick Reminder from any app. Press Escape to cancel recording.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let registrationError = store.registrationError {
                Text(registrationError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Shortcut error: \(registrationError)")
            }
        }
        .onDisappear(perform: stopRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            stopRecording()
        }
    }

    private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        store.beginRecording()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            let candidate = GlobalShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: event.modifierFlags
            )
            if candidate.isValid {
                if store.setShortcut(candidate) {
                    stopRecording()
                } else {
                    store.beginRecording()
                }
            }
            return nil
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        isRecording = false
        store.endRecording()
    }
}
