import Foundation

/// Maps display brightness to keyboard backlight brightness.
///
/// Both sides are fractions from 0 to 1, the same scale the brightness sliders
/// in Control Center use. The default is a straight line: the keyboard sits at
/// the same level as the display.
public struct Curve: Equatable {
    /// Keyboard brightness when the display is at its dimmest.
    public var minimum: Double
    /// Keyboard brightness when the display is at its brightest.
    public var maximum: Double
    /// Above 1 keeps the keyboard dimmer through the middle of the range, below 1 brighter.
    public var gamma: Double

    public init(minimum: Double = 0, maximum: Double = 1, gamma: Double = 1) {
        self.minimum = minimum
        self.maximum = maximum
        self.gamma = gamma
    }

    public func keyboard(forDisplay display: Double) -> Double {
        let x = min(max(display, 0), 1)
        return minimum + (maximum - minimum) * pow(x, gamma)
    }
}
