import Foundation
import KBSyncCore
import KBSyncSystem

let usage = """
kbsync \(version): keep the MacBook keyboard backlight in step with the screen brightness.

Usage:
  kbsync run [options]       follow the display in the foreground (Ctrl-C to stop)
  kbsync status [options]    show both brightness levels and whether the agent is running
  kbsync install [options]   run in the background and at login, with these options
  kbsync uninstall           stop the background agent and remove it

Options:
  --min <0-100>   keyboard brightness when the display is at its dimmest (default 0)
  --max <0-100>   keyboard brightness when the display is at its brightest (default 100)
  --gamma <x>     curve shape: above 1 keeps the keyboard dimmer mid-range (default 1)
  --fade <ms>     how long each keyboard change fades for (default 250)
  --keep-auto     leave "Adjust keyboard brightness in low light" on
  -v, --verbose   log every change

"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("kbsync: \(message)\n".utf8))
    exit(1)
}

func status(_ options: SyncOptions) throws {
    let display = try BuiltInDisplay()
    let keyboard = try BuiltInKeyboard()
    func row(_ name: String, _ value: String) {
        print(name.padding(toLength: 12, withPad: " ", startingAt: 0) + value)
    }

    guard let displayLevel = display.brightness() else { throw BridgeError.noDisplay }
    let target = options.curve.keyboard(forDisplay: displayLevel)
    row("display", percent(displayLevel))
    if keyboard.isIdleDimmed() {
        row("keyboard", "off after inactivity; target \(percent(target))")
    } else {
        row("keyboard", "\(percent(keyboard.brightness() ?? 0)) (target \(percent(target)))")
    }
    row("low light", keyboard.isAutoBrightnessEnabled()
        ? "on: macOS also adjusts the keyboard; kbsync turns this off while it runs"
        : "off")
    let idle = keyboard.idleDimSeconds()
    row("idle off", idle > 0 ? "after \(String(format: "%g", idle)) s of inactivity" : "never")
    row("agent", Agent.state().rawValue)
}

do {
    switch try CommandParser.parse(Array(CommandLine.arguments.dropFirst())) {
    case .run(let options):
        let daemon: Daemon
        do {
            daemon = Daemon(options: options, engine: try Engine(curve: options.curve, fadeMilliseconds: options.fadeMilliseconds))
        } catch BridgeError.noKeyboard {
            // A clean exit, so launchd doesn't keep restarting the agent on a Mac without a backlight.
            print("kbsync: no backlit keyboard found, nothing to do")
            exit(0)
        }
        daemon.run()
    case .status(let options):
        try status(options)
    case .install(let options):
        // Fail here, not in the background, if this Mac can't be driven.
        _ = try BuiltInDisplay()
        _ = try BuiltInKeyboard()
        try Agent.install(flags: options.flags)
    case .uninstall:
        try Agent.uninstall()
    case .help:
        print(usage, terminator: "")
    case .version:
        print("kbsync \(version)")
    }
} catch let error as UsageError {
    fail("\(error)\n\n\(usage)")
} catch {
    fail("\(error)")
}
