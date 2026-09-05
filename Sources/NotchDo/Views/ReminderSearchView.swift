import SwiftUI

struct ReminderSearchView: View {
    @Binding var query: String
    let focusRequest: Int
    let resultCount: Int
    let totalCount: Int
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .accessibilityHidden(true)

            TextField("Search reminders", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .focused($isFocused)
                .accessibilityLabel("Search reminders")
                .accessibilityValue(resultDescription)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close search")
            .help("Close Search")
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(.white.opacity(isFocused ? 0.18 : 0.09), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.12), value: isFocused)
        .onAppear(perform: restoreFocus)
        .onChange(of: focusRequest) { _, _ in
            restoreFocus()
        }
    }

    private var resultDescription: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Showing all \(totalCount) reminders"
        }
        return "\(resultCount) of \(totalCount) reminders"
    }

    private func restoreFocus() {
        DispatchQueue.main.async {
            isFocused = true
        }
    }
}
