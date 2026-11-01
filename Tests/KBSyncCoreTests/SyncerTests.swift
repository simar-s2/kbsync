import Testing
@testable import KBSyncCore

private final class FakeDisplay: DisplayBrightness {
    var level: Double? = 0.5

    func brightness() -> Double? { level }
}

/// Behaves like the real backlight: writes while idle-dimmed are accepted but ignored.
private final class FakeKeyboard: KeyboardBacklight {
    var level = 0.3
    var idleDimmed = false
    var autoBrightness = true
    var writesFail = false
    private(set) var writes: [(value: Double, fade: Int)] = []

    func brightness() -> Double? { idleDimmed ? 0 : level }
    func isIdleDimmed() -> Bool { idleDimmed }

    func setBrightness(_ value: Double, fadeMilliseconds: Int) -> Bool {
        guard !writesFail else { return false }
        writes.append((value, fadeMilliseconds))
        if !idleDimmed { level = value }
        return true
    }

    func isAutoBrightnessEnabled() -> Bool { autoBrightness }

    func setAutoBrightnessEnabled(_ enabled: Bool) -> Bool {
        autoBrightness = enabled
        return true
    }
}

@Suite struct SyncerTests {
    private let display = FakeDisplay()
    private let keyboard = FakeKeyboard()

    private func syncer(_ curve: Curve = Curve(), fade: Int = 250) -> Syncer {
        Syncer(display: display, keyboard: keyboard, curve: curve, fadeMilliseconds: fade)
    }

    @Test func movesTheKeyboardToTheDisplayLevel() {
        let syncer = syncer(fade: 400)
        #expect(syncer.sync() == .set(display: 0.5, keyboard: 0.5))
        #expect(keyboard.level == 0.5)
        #expect(keyboard.writes.map(\.fade) == [400])
    }

    @Test func followsEveryChange() {
        let syncer = syncer(Curve(maximum: 0.5))
        for level in [0.2, 0.9, 0.0, 1.0] {
            display.level = level
            syncer.sync()
            #expect(keyboard.level == level * 0.5)
        }
        #expect(keyboard.writes.count == 4)
    }

    @Test func skipsWritesWithinTolerance() {
        keyboard.level = 0.503
        #expect(syncer().sync() == .unchanged(display: 0.5, keyboard: 0.5))
        #expect(keyboard.writes.isEmpty)
    }

    @Test func correctsAKeyboardSomethingElseMoved() {
        let syncer = syncer()
        syncer.sync()
        keyboard.level = 0.9
        #expect(syncer.sync() == .set(display: 0.5, keyboard: 0.5))
        #expect(keyboard.level == 0.5)
    }

    @Test func waitsWhileTheKeyboardIsDimmedThenCatchesUp() {
        let syncer = syncer()
        keyboard.idleDimmed = true
        display.level = 0.8
        #expect(syncer.sync() == .deferred(display: 0.8, keyboard: 0.8))
        #expect(keyboard.writes.isEmpty)

        keyboard.idleDimmed = false
        #expect(syncer.sync() == .set(display: 0.8, keyboard: 0.8))
        #expect(keyboard.level == 0.8)
    }

    @Test func doesNothingWithoutTheDisplay() {
        display.level = nil
        #expect(syncer().sync() == .displayUnavailable)
        #expect(keyboard.writes.isEmpty)
    }

    @Test func reportsAFailedWrite() {
        keyboard.writesFail = true
        #expect(syncer().sync() == .failed(display: 0.5, keyboard: 0.5))
    }

    @Test func takesOverAndRestoresAutoBrightness() {
        let syncer = syncer()
        #expect(syncer.takeOverAutoBrightness())
        #expect(!keyboard.autoBrightness)
        #expect(syncer.restoreAutoBrightness())
        #expect(keyboard.autoBrightness)
        #expect(!syncer.restoreAutoBrightness())
    }

    @Test func leavesAutoBrightnessOffIfItWasAlreadyOff() {
        keyboard.autoBrightness = false
        let syncer = syncer()
        #expect(!syncer.takeOverAutoBrightness())
        #expect(!syncer.restoreAutoBrightness())
        #expect(!keyboard.autoBrightness)
    }
}
