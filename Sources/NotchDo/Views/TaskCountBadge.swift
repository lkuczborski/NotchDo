import SwiftUI

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
