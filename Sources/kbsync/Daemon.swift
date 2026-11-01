import Foundation
import KBSyncCore
import KBSyncSystem

/// `kbsync run`: runs the engine in the foreground and logs until signalled.
final class Daemon {
    private let options: SyncOptions
    private let engine: Engine
    private var signalSources: [DispatchSourceSignal] = []

    init(options: SyncOptions, engine: Engine) {
        self.options = options
        self.engine = engine
    }

    func run() -> Never {
        // Under launchd stdout is a file; flush each line so the log stays current.
        setvbuf(stdout, nil, _IOLBF, 0)

        let curve = options.curve
        log("kbsync \(version): keyboard follows the built-in display "
            + "(\(Int((curve.minimum * 100).rounded()))–\(percent(curve.maximum)), gamma \(String(format: "%g", curve.gamma)), "
            + "\(options.fadeMilliseconds) ms fade)")
        if !options.keepAutoBrightness, engine.takeOverAutoBrightness() {
            log("turned off \"Adjust keyboard brightness in low light\" until kbsync stops")
        }

        for signalNumber in [SIGINT, SIGTERM, SIGHUP] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [unowned self] in stop() }
            source.resume()
            signalSources.append(source)
        }

        engine.onSync = { [options] result in
            switch result {
            case .set(let display, let keyboard):
                if options.verbose { log("display \(percent(display)) → keyboard \(percent(keyboard))") }
            case .deferred(let display, let keyboard):
                if options.verbose { log("display \(percent(display)), keyboard is idle-dimmed; \(percent(keyboard)) when it wakes") }
            case .failed(_, let keyboard):
                log("couldn't set the keyboard to \(percent(keyboard))")
            case .unchanged, .displayUnavailable:
                break
            }
        }
        engine.start()
        RunLoop.main.run()
        fatalError("the main run loop exited")
    }

    private func stop() -> Never {
        if engine.stop() {
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
