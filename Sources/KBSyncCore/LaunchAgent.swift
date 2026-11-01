import Foundation

/// The per-user launchd job that runs `kbsync run` at login.
public enum LaunchAgent {
    public static let label = "com.github.simar-s2.kbsync"

    public static func plistURL(home: URL) -> URL {
        home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static func logURL(home: URL) -> URL {
        home.appendingPathComponent("Library/Logs/kbsync.log")
    }

    public static func plist(executable: String, flags: [String], logPath: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executable, "run"] + flags,
            "RunAtLoad": true,
            // Restart after a crash, but not after a clean exit (e.g. no backlit keyboard).
            "KeepAlive": ["SuccessfulExit": false],
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
        ]
    }

    public static func plistData(executable: String, flags: [String], logPath: String) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: plist(executable: executable, flags: flags, logPath: logPath),
            format: .xml,
            options: 0
        )
    }
}
