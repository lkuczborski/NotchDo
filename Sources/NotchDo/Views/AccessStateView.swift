import SwiftUI

struct AccessStateView: View {
    let symbol: String
    let title: String
    let message: String
    let showsProgress: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.055))
                    .frame(width: 52, height: 52)

                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.notchAccent)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.notchAccent)
                }
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.78))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.notchAccent, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
