import SwiftUI

struct NotchRootView: View {
    @ObservedObject var store: RemindersStore
    @ObservedObject var layout: NotchLayoutModel
    @ObservedObject var interaction: NotchInteractionModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rowCollapseRequest = 0
    @State private var expandedCountFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .top) {
            expandingSurface
            taskCountBadge
        }
        .frame(
            width: layout.metrics.expandedSize.width,
            height: layout.metrics.expandedSize.height,
            alignment: .top
        )
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .coordinateSpace(name: NotchCoordinateSpace.root)
        .onPreferenceChange(TaskCountBadgeFrameKey.self) { frame in
            expandedCountFrame = frame
        }
        .onTapGesture {
            interaction.expand()
        }
        .animation(surfaceAnimation, value: isExpanded)
    }

    private var expandingSurface: some View {
        ZStack(alignment: .top) {
            Color.black

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: layout.metrics.bridgeHeight + 2)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: collapseReminderRows)
                    .accessibilityLabel("NotchDo")

                expandedContent
            }
            .frame(
                width: layout.metrics.expandedSize.width,
                height: layout.metrics.expandedSize.height
            )
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
        .mask(alignment: .top) {
            surfaceShape
                .frame(width: surfaceSize.width, height: surfaceSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .compositingGroup()
    }

    private var isExpanded: Bool {
        interaction.isExpanded
    }

    private var surfaceSize: CGSize {
        isExpanded ? layout.metrics.expandedSize : layout.metrics.collapsedSize
    }

    private var expandedContent: some View {
        VStack(spacing: 12) {
            NotchHeaderView(
                store: store,
                onInteraction: collapseReminderRows
            ) { isPresented in
                    interaction.updateTransientInteraction(isPresented)
                }

            content

            if store.authorization == .fullAccess {
                ComposerView(
                    store: store,
                    isActive: isExpanded,
                    onInteraction: collapseReminderRows
                )
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var taskCountBadge: some View {
        TaskCountBadge(
            count: store.reminders.count,
            color: store.selectedCalendarColor,
            diameter: isExpanded ? 22 : 20
        )
        .position(taskCountBadgePosition)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.reminders.count) open reminders")
        .zIndex(4)
    }

    private var taskCountBadgePosition: CGPoint {
        if isExpanded, !expandedCountFrame.isEmpty {
            return CGPoint(x: expandedCountFrame.midX, y: expandedCountFrame.midY)
        }

        return CGPoint(
            x: layout.metrics.expandedSize.width / 2
                - layout.metrics.collapsedSize.width / 2
                - 18,
            y: layout.metrics.bridgeHeight / 2
        )
    }

    @ViewBuilder
    private var content: some View {
        switch store.authorization {
        case .fullAccess:
            ReminderListView(
                store: store,
                isPanelExpanded: isExpanded,
                collapseRequest: rowCollapseRequest,
                onTransientInteraction: interaction.updateTransientInteraction
            )
        case .requesting:
            AccessStateView(
                symbol: "checklist",
                title: "Connecting to Reminders",
                message: "Your tasks stay in Apple Reminders.",
                showsProgress: true,
                actionTitle: nil,
                action: nil
            )
        case .denied, .restricted:
            AccessStateView(
                symbol: "lock.fill",
                title: "Reminders access is off",
                message: "Allow NotchDo in Privacy & Security to show and update your tasks.",
                showsProgress: false,
                actionTitle: "Open Settings",
                action: AppActions.openRemindersPrivacySettings
            )
        case .notDetermined:
            AccessStateView(
                symbol: "checklist",
                title: "Use Apple Reminders",
                message: "No separate account or task database — just your existing lists.",
                showsProgress: false,
                actionTitle: "Continue",
                action: { Task { await store.requestAccess() } }
            )
        }
    }

    private var surfaceShape: NotchSurfaceShape {
        NotchSurfaceShape(
            topCornerRadius: isExpanded ? 12 : 5,
            bottomCornerRadius: isExpanded ? 28 : 12
        )
    }

    private var surfaceAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .smooth(duration: isExpanded ? 0.28 : 0.22, extraBounce: 0)
    }

    private func collapseReminderRows() {
        rowCollapseRequest &+= 1
    }
}
