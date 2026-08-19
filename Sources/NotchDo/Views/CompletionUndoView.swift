import SwiftUI

struct CompletionUndoView: View {
    let reminderTitle: String
    let color: Color
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text("Completed")
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 8)

            Button("Undo", action: onUndo)
                .buttonStyle(.plain)
                .foregroundStyle(color)
                .accessibilityLabel("Undo completion of \(reminderTitle)")
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(.white.opacity(0.045), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}
