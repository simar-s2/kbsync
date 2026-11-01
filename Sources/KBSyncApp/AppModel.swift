import AppKit
import KBSyncCore
import KBSyncSystem
import os
import ServiceManagement

/// Each keyboard change, visible with `log stream --predicate 'subsystem == "com.github.simar-s2.kbsync.menubar"'`.
private let logger = Logger(subsystem: "com.github.simar-s2.kbsync.menubar", category: "sync")

/// What the menu shows and controls. Settings live in UserDefaults; the
/// engine does the work.
final class AppModel: ObservableObject {
    private enum Key {
        static let isOn = "isOn"
        static let maxPercent = "maxPercent"
        static let minPercent = "minPercent"
    }

    @Published var isOn: Bool {
        didSet {
            defaults.set(isOn, forKey: Key.isOn)
            applyOnOff()
        }
    }

    @Published var maxPercent: Double {
        didSet {
            if minPercent > maxPercent { minPercent = maxPercent }
            defaults.set(maxPercent, forKey: Key.maxPercent)
            applyCurve()
        }
    }

    @Published var minPercent: Double {
        didSet {
            if maxPercent < minPercent { maxPercent = minPercent }
            defaults.set(minPercent, forKey: Key.minPercent)
            applyCurve()
        }
    }

    @Published private(set) var displayLevel: Double?
    @Published private(set) var keyboardLevel: Double?
    @Published private(set) var keyboardIdle = false
    @Published private(set) var launchAtLogin = false
    /// The command-line agent drives the keyboard too; running both makes them fight.
    @Published private(set) var agentRunning = false
    @Published private(set) var problem: String?

    private let defaults: UserDefaults
    private let engine: Engine?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.isOn: true, Key.maxPercent: 100.0, Key.minPercent: 0.0])
        let maximum = defaults.double(forKey: Key.maxPercent)
        let minimum = defaults.double(forKey: Key.minPercent)
        isOn = defaults.bool(forKey: Key.isOn)
        maxPercent = maximum
        minPercent = minimum

        do {
            engine = try Engine(curve: Curve(minimum: minimum / 100, maximum: maximum / 100))
        } catch {
            engine = nil
            problem = "\(error)"
        }
        engine?.onSync = { [weak self] result in self?.show(result) }
        applyOnOff()
        refresh()
    }

    var statusLine: String {
        guard engine != nil else { return "Not available on this Mac" }
        guard isOn else { return "Off. macOS controls the keyboard." }
        guard let display = displayLevel else { return "Waiting for the built-in display" }
        if keyboardIdle { return "Screen \(percent(display)) · keyboard off while idle" }
        return "Screen \(percent(display)) · Keyboard \(percent(keyboardLevel ?? 0))"
    }

    /// Re-reads everything; called whenever the menu opens.
    func refresh() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        agentRunning = Self.commandLineAgentIsRunning()
        guard let engine else { return }
        displayLevel = engine.display.brightness()
        keyboardIdle = engine.keyboard.isIdleDimmed()
        keyboardLevel = keyboardIdle ? nil : engine.keyboard.brightness()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            problem = "Couldn't change Launch at login: \(error.localizedDescription)"
        }
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Hands the keyboard back to macOS; called when the app quits.
    func stop() {
        engine?.stop()
    }

    private func applyOnOff() {
        guard let engine else { return }
        if isOn {
            _ = engine.takeOverAutoBrightness()
            engine.start()
        } else {
            engine.stop()
        }
        refresh()
    }

    private func applyCurve() {
        engine?.curve = Curve(minimum: minPercent / 100, maximum: maxPercent / 100)
    }

    private func show(_ result: SyncResult) {
        switch result {
        case .set(let display, let keyboard), .unchanged(let display, let keyboard):
            if case .set = result {
                logger.info("display \(percent(display), privacy: .public) → keyboard \(percent(keyboard), privacy: .public)")
            }
            displayLevel = display
            keyboardLevel = keyboard
            keyboardIdle = false
        case .deferred(let display, _):
            displayLevel = display
            keyboardIdle = true
        case .failed, .displayUnavailable:
            break
        }
    }

    private static func commandLineAgentIsRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(getuid())/\(LaunchAgent.label)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}
