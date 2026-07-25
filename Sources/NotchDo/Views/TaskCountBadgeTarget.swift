import SwiftUI

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
