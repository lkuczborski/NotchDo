import SwiftUI

enum NotchCoordinateSpace {
    static let root = "NotchDo.Root"
}

struct TaskCountBadge: View {
    let count: Int
    let color: Color
    let diameter: CGFloat

    var body: some View {
        Text(count, format: .number)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .foregroundStyle(.black.opacity(0.72))
            .contentTransition(.numericText())
            .frame(width: diameter, height: diameter)
            .background(color, in: Circle())
    }
}

struct TaskCountBadgeTarget: View {
    var body: some View {
        Color.clear
            .frame(width: 22, height: 22)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: TaskCountBadgeFrameKey.self,
                        value: geometry.frame(in: .named(NotchCoordinateSpace.root))
                    )
                }
            }
    }
}

struct TaskCountBadgeFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextFrame = nextValue()
        if !nextFrame.isEmpty {
            value = nextFrame
        }
    }
}
