import Testing
@testable import NotchDo

@Suite("Vertical scroll indicator metrics")
struct VerticalScrollIndicatorMetricsTests {
    @Test("Content that fits the viewport does not scroll")
    func contentFits() {
        let metrics = VerticalScrollIndicatorMetrics(
            contentOffset: 0,
            contentHeight: 200,
            viewportHeight: 200
        )

        #expect(!metrics.isScrollable)
    }

    @Test("Thumb size and offset represent the visible portion")
    func thumbGeometry() {
        let metrics = VerticalScrollIndicatorMetrics(
            contentOffset: 150,
            contentHeight: 600,
            viewportHeight: 300
        )

        #expect(metrics.isScrollable)
        #expect(metrics.thumbHeight(in: 300) == 150)
        #expect(metrics.thumbOffset(in: 300) == 75)
    }

    @Test("Thumb offset is clamped to its track")
    func offsetClamping() {
        let beforeStart = VerticalScrollIndicatorMetrics(
            contentOffset: -40,
            contentHeight: 600,
            viewportHeight: 300
        )
        let pastEnd = VerticalScrollIndicatorMetrics(
            contentOffset: 400,
            contentHeight: 600,
            viewportHeight: 300
        )

        #expect(beforeStart.thumbOffset(in: 300) == 0)
        #expect(pastEnd.thumbOffset(in: 300) == 150)
    }
}
