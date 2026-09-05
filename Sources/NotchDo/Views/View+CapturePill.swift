import SwiftUI

extension View {
    func capturePill(selected: Bool = false) -> some View {
        self
            .padding(.horizontal, 10)
            .frame(height: 28)
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .background(selected ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.05), in: Capsule())
            .contentShape(Capsule())
    }
}
