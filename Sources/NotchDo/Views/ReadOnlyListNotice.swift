import SwiftUI

struct ReadOnlyListNotice: View {
    var body: some View {
        Label("This list is read-only", systemImage: "lock.fill")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11))
            .accessibilityHint("Reminders can be viewed but not changed")
    }
}
