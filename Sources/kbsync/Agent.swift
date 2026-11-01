import Foundation
import KBSyncCore

/// `kbsync install` and `kbsync uninstall`: manage the per-user launch agent.
enum Agent {
    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    private static var domain: String { "gui/\(getuid())" }
    private static var service: String { "\(domain)/\(LaunchAgent.label)" }

    enum State: String {
        case running = "running"
        case stopped = "installed, not running"
        case notInstalled = "not installed"
    }

    static func state() -> State {
        guard FileManager.default.fileExists(atPath: LaunchAgent.plistURL(home: home).path) else { return .notInstalled }
        let (status, output) = launchctl(["print", service])
        return status == 0 && output.contains("state = running") ? .running : .stopped
    }

    static func install(flags: [String]) throws {
        guard let resolved = Bundle.main.executableURL?.resolvingSymlinksInPath().path else {
            throw AgentError("couldn't work out where the kbsync binary is")
        }
        let executable = LaunchAgent.stableExecutablePath(resolved)
        if executable.contains("/.build/") {
            print("note: the agent will run \(executable), inside the build folder.")
            print("      `make install` puts kbsync somewhere that survives a clean build.")
        }

        let plistURL = LaunchAgent.plistURL(home: home)
        let logURL = LaunchAgent.logURL(home: home)
        let files = FileManager.default
        try files.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try LaunchAgent.plistData(executable: executable, flags: flags, logPath: logURL.path).write(to: plistURL, options: .atomic)

        unload()
        let (status, output) = launchctl(["bootstrap", domain, plistURL.path])
        guard status == 0 else { throw AgentError("launchctl bootstrap failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))") }

        print("kbsync is running in the background and will start at login.")
        print("log: \(logURL.path.replacingOccurrences(of: home.path, with: "~"))")
    }

    static func uninstall() throws {
        let plistURL = LaunchAgent.plistURL(home: home)
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            print("kbsync isn't installed.")
            return
        }
        unload()
        try FileManager.default.removeItem(at: plistURL)
        print("kbsync is stopped and won't start at login.")
    }

    /// Stops the job if it is loaded and waits for launchd to forget it, so a
    /// bootstrap straight after doesn't race the old instance.
    private static func unload() {
        guard launchctl(["print", service]).status == 0 else { return }
        _ = launchctl(["bootout", service])
        for _ in 0..<50 where launchctl(["print", service]).status == 0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, "\(error)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

struct AgentError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
