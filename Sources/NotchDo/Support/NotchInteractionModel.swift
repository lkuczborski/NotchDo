import Combine
import Foundation

@MainActor
final class NotchInteractionModel: ObservableObject {
    @Published private(set) var isExpanded = false

    var onExpansionChange: ((Bool) -> Void)?
    var onInteraction: (() -> Void)?

    private(set) var isPointerInside = false
    private var hasTransientInteraction = false
    private var transientDismissWorkItem: DispatchWorkItem?

    func updatePointerInside(_ isInside: Bool) {
        guard isPointerInside != isInside else { return }
        isPointerInside = isInside

        if isInside {
            transientDismissWorkItem?.cancel()
            onInteraction?()
            expand()
        } else if !hasTransientInteraction {
            collapse()
        }
    }

    func registerInteraction() {
        onInteraction?()
    }

    func updateTransientInteraction(_ isActive: Bool) {
        transientDismissWorkItem?.cancel()
        hasTransientInteraction = isActive
        if isActive {
            expand()
        } else if !isPointerInside {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, !self.hasTransientInteraction, !self.isPointerInside else { return }
                self.collapse()
            }
            transientDismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
    }

    func expand() {
        setExpanded(true)
    }

    func collapse() {
        guard !hasTransientInteraction else { return }
        setExpanded(false)
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        onExpansionChange?(expanded)
    }
}
