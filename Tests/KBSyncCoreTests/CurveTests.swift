import Testing
@testable import KBSyncCore

@Suite struct CurveTests {
    @Test func defaultCurveMatchesTheDisplay() {
        let curve = Curve()
        for level in [0, 0.25, 0.5, 0.8, 1] {
            #expect(curve.keyboard(forDisplay: level) == level)
        }
    }

    @Test func minAndMaxSetTheEnds() {
        let curve = Curve(minimum: 0.1, maximum: 0.6)
        #expect(curve.keyboard(forDisplay: 0) == 0.1)
        #expect(curve.keyboard(forDisplay: 1) == 0.6)
        #expect(abs(curve.keyboard(forDisplay: 0.5) - 0.35) < 1e-12)
    }

    @Test func gammaAboveOneKeepsTheMiddleDimmer() {
        let curve = Curve(gamma: 2)
        #expect(curve.keyboard(forDisplay: 0.5) == 0.25)
        #expect(curve.keyboard(forDisplay: 1) == 1)
    }

    @Test func gammaBelowOneKeepsTheMiddleBrighter() {
        #expect(Curve(gamma: 0.5).keyboard(forDisplay: 0.25) == 0.5)
    }

    @Test func displayValuesOutsideTheRangeAreClamped() {
        let curve = Curve(minimum: 0.2, maximum: 0.8)
        #expect(curve.keyboard(forDisplay: -0.3) == 0.2)
        #expect(curve.keyboard(forDisplay: 1.7) == 0.8)
    }
}
