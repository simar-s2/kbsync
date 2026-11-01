import Foundation

/// The built-in display, reduced to what syncing needs.
public protocol DisplayBrightness: AnyObject {
    /// Brightness from 0 to 1, or nil when the display is unavailable (lid closed).
    func brightness() -> Double?
}

/// The keyboard backlight, reduced to what syncing needs.
public protocol KeyboardBacklight: AnyObject {
    func brightness() -> Double?
    /// True while macOS holds the backlight off by itself: idle dimming, a
    /// closed lid or a sleeping display. Writes made then do not stick.
    func isAsleep() -> Bool
    func setBrightness(_ value: Double, fadeMilliseconds: Int) -> Bool
    /// The "Adjust keyboard brightness in low light" setting.
    func isAutoBrightnessEnabled() -> Bool
    func setAutoBrightnessEnabled(_ enabled: Bool) -> Bool
}

public enum SyncResult: Equatable {
    /// The display brightness could not be read.
    case displayUnavailable
    /// The keyboard is asleep; the target is applied when it wakes.
    case deferred(display: Double, keyboard: Double)
    /// The keyboard was already within tolerance of the target.
    case unchanged(display: Double, keyboard: Double)
    case set(display: Double, keyboard: Double)
    case failed(display: Double, keyboard: Double)
}

/// Keeps the keyboard backlight on the curve. Not thread-safe: call it from one queue.
public final class Syncer {
    /// Differences smaller than this are not worth a write (half a percent).
    public static let tolerance = 0.005

    private let display: DisplayBrightness
    private let keyboard: KeyboardBacklight
    private let curve: Curve
    private let fadeMilliseconds: Int
    private var turnedOffAutoBrightness = false

    public init(display: DisplayBrightness, keyboard: KeyboardBacklight, curve: Curve, fadeMilliseconds: Int) {
        self.display = display
        self.keyboard = keyboard
        self.curve = curve
        self.fadeMilliseconds = fadeMilliseconds
    }

    /// Reads the display and puts the keyboard where the curve says. Called on
    /// every display brightness change, at startup, when the keyboard wakes from
    /// idle dimming, and after sleep.
    @discardableResult
    public func sync() -> SyncResult {
        guard let value = display.brightness() else { return .displayUnavailable }
        let target = curve.keyboard(forDisplay: value)
        if keyboard.isAsleep() {
            return .deferred(display: value, keyboard: target)
        }
        if let current = keyboard.brightness(), abs(current - target) < Self.tolerance {
            return .unchanged(display: value, keyboard: target)
        }
        guard keyboard.setBrightness(target, fadeMilliseconds: fadeMilliseconds) else {
            return .failed(display: value, keyboard: target)
        }
        return .set(display: value, keyboard: target)
    }

    /// Turns off the ambient light sensor's control of the keyboard, which
    /// would otherwise keep moving it away from the curve. Returns true if it
    /// was on and is now off.
    public func takeOverAutoBrightness() -> Bool {
        guard keyboard.isAutoBrightnessEnabled() else { return false }
        turnedOffAutoBrightness = keyboard.setAutoBrightnessEnabled(false)
        return turnedOffAutoBrightness
    }

    /// Undoes `takeOverAutoBrightness`. Returns true if the setting was turned back on.
    public func restoreAutoBrightness() -> Bool {
        guard turnedOffAutoBrightness else { return false }
        turnedOffAutoBrightness = false
        return keyboard.setAutoBrightnessEnabled(true)
    }
}
