import AppKit
import KBSyncCore

/// Keeps the keyboard on the curve: wires the system's display, keyboard,
/// reconfiguration and wake notifications to a Syncer. One per process, used
/// from the main queue. Both the command-line tool and the menu bar app run one.
public final class Engine {
    public let display: BuiltInDisplay
    public let keyboard: BuiltInKeyboard
    private let syncer: Syncer
    private var observing = false
    public private(set) var isRunning = false

    /// Called on the main queue after every sync, for logs and the menu.
    public var onSync: ((SyncResult) -> Void)?

    public init(curve: Curve = Curve(), fadeMilliseconds: Int = 250) throws {
        display = try BuiltInDisplay()
        keyboard = try BuiltInKeyboard()
        syncer = Syncer(display: display, keyboard: keyboard, curve: curve, fadeMilliseconds: fadeMilliseconds)
    }

    /// Changing the curve while running moves the keyboard straight away.
    public var curve: Curve {
        get { syncer.curve }
        set {
            syncer.curve = newValue
            sync()
        }
    }

    /// Turns off "Adjust keyboard brightness in low light", which would
    /// otherwise keep moving the keyboard. Returns true if it was on.
    public func takeOverAutoBrightness() -> Bool {
        syncer.takeOverAutoBrightness()
    }

    public func start() {
        if !observing { observe() }
        isRunning = true
        sync()
    }

    /// Stops following the display and hands the keyboard back to macOS.
    /// Returns true if it turned "Adjust keyboard brightness in low light" back on.
    @discardableResult
    public func stop() -> Bool {
        isRunning = false
        return syncer.restoreAutoBrightness()
    }

    private func sync() {
        guard isRunning else { return }
        onSync?(syncer.sync())
    }

    private func observe() {
        observing = true
        display.observe { [unowned self] in sync() }

        // Writes made while macOS has the backlight dimmed don't stick, so catch
        // up once it is lit again. The short delay lets both dim flags settle.
        keyboard.observeSleep { [unowned self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
                if !keyboard.isIdleDimmed() { sync() }
            }
        }

        CGDisplayRegisterReconfigurationCallback({ _, flags, context in
            guard !flags.contains(.beginConfigurationFlag), let context else { return }
            let engine = Unmanaged<Engine>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                engine.display.reattach()
                engine.sync()
            }
        }, Unmanaged.passUnretained(self).toOpaque())

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [unowned self] _ in sync() }
    }
}
