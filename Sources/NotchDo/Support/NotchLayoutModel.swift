import AppKit
import Combine

@MainActor
final class NotchLayoutModel: ObservableObject {
    @Published private(set) var metrics: NotchMetrics

    init(screen: NSScreen) {
        metrics = .resolve(for: screen)
    }

    init(geometry: NotchScreenGeometry) {
        metrics = .resolve(for: geometry)
    }

    func update(for screen: NSScreen) {
        update(for: NotchScreenGeometry(screen: screen))
    }

    func update(for geometry: NotchScreenGeometry) {
        let newMetrics = NotchMetrics.resolve(for: geometry)
        if newMetrics != metrics {
            metrics = newMetrics
        }
    }
}
