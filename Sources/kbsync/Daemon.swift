import AppKit
import KBSyncCore

/// `kbsync run`: wires the system notifications to the syncer and runs until signalled.
final class Daemon {
    private let options: SyncOptions
    private let display: BuiltInDisplay
    private let keyboard: BuiltInKeyboard
    private let syncer: Syncer
    private var signalSources: [DispatchSourceSignal] = []

    init(options: SyncOptions, display: BuiltInDisplay, keyboard: BuiltInKeyboard) {
        self.options = options
        self.display = display
        self.keyboard = keyboard
        syncer = Syncer(display: display, keyboard: keyboard, curve: options.curve, fadeMilliseconds: options.fadeMilliseconds)
    }

    func run() -> Never {
        // Under launchd stdout is a file; flush each line so the log stays current.
        setvbuf(stdout, nil, _IOLBF, 0)

        let curve = options.curve
        log("kbsync \(version): keyboard follows the built-in display "
            + "(\(Int((curve.minimum * 100).rounded()))–\(percent(curve.maximum)), gamma \(String(format: "%g", curve.gamma)), "
            + "\(options.fadeMilliseconds) ms fade)")
        if !options.keepAutoBrightness, syncer.takeOverAutoBrightness() {
            log("turned off \"Adjust keyboard brightness in low light\" until kbsync stops")
        }

        display.observe { [unowned self] in sync() }

        // Writes made while macOS has the backlight dimmed don't stick, so catch
        // up once it is lit again. The short delay lets both dim flags settle.
        keyboard.observeSleep { [unowned self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
                if !keyboard.isAsleep() { sync() }
            }
        }

        CGDisplayRegisterReconfigurationCallback({ _, flags, context in
            guard !flags.contains(.beginConfigurationFlag), let context else { return }
            let daemon = Unmanaged<Daemon>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { daemon.displaysChanged() }
        }, Unmanaged.passUnretained(self).toOpaque())

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [unowned self] _ in sync() }

        for signalNumber in [SIGINT, SIGTERM, SIGHUP] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [unowned self] in stop() }
            source.resume()
            signalSources.append(source)
        }

        sync()
        RunLoop.main.run()
        fatalError("the main run loop exited")
    }

    private func displaysChanged() {
        display.reattach()
        sync()
    }

    private func sync() {
        switch syncer.sync() {
        case .set(let display, let keyboard):
            if options.verbose { log("display \(percent(display)) → keyboard \(percent(keyboard))") }
        case .deferred(let display, let keyboard):
            if options.verbose { log("display \(percent(display)), keyboard is dimmed; \(percent(keyboard)) when it wakes") }
        case .failed(_, let keyboard):
            log("couldn't set the keyboard to \(percent(keyboard))")
        case .unchanged, .displayUnavailable:
            break
        }
    }

    private func stop() -> Never {
        if syncer.restoreAutoBrightness() {
            log("turned \"Adjust keyboard brightness in low light\" back on")
        }
        log("stopped")
        exit(0)
    }
}

private let timestampFormat: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

func log(_ message: String) {
    print("\(timestampFormat.string(from: Date()))  \(message)")
}

func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}
