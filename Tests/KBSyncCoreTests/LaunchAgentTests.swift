import Foundation
import Testing
@testable import KBSyncCore

@Suite struct LaunchAgentTests {
    @Test func pathsLiveInTheUserLibrary() {
        let home = URL(fileURLWithPath: "/Users/someone")
        #expect(LaunchAgent.plistURL(home: home).path == "/Users/someone/Library/LaunchAgents/com.github.simar-s2.kbsync.plist")
        #expect(LaunchAgent.logURL(home: home).path == "/Users/someone/Library/Logs/kbsync.log")
    }

    @Test func plistRunsKbsyncWithTheGivenFlags() throws {
        let data = try LaunchAgent.plistData(
            executable: "/usr/local/bin/kbsync", flags: ["--max", "70"], logPath: "/tmp/kbsync.log"
        )
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        #expect(plist["Label"] as? String == "com.github.simar-s2.kbsync")
        #expect(plist["ProgramArguments"] as? [String] == ["/usr/local/bin/kbsync", "run", "--max", "70"])
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(plist["KeepAlive"] as? [String: Bool] == ["SuccessfulExit": false])
        #expect(plist["StandardOutPath"] as? String == "/tmp/kbsync.log")
        #expect(plist["StandardErrorPath"] as? String == "/tmp/kbsync.log")
    }

    @Test func homebrewInstallsPointAtTheStableOptLink() {
        #expect(LaunchAgent.stableExecutablePath("/opt/homebrew/Cellar/kbsync/0.2.0/bin/kbsync")
            == "/opt/homebrew/opt/kbsync/bin/kbsync")
        #expect(LaunchAgent.stableExecutablePath("/usr/local/Cellar/kbsync/0.2.0_1/bin/kbsync")
            == "/usr/local/opt/kbsync/bin/kbsync")
        #expect(LaunchAgent.stableExecutablePath("/usr/local/bin/kbsync") == "/usr/local/bin/kbsync")
    }

    @Test func plistIsValidXML() throws {
        let data = try LaunchAgent.plistData(executable: "/bin/kbsync", flags: [], logPath: "/tmp/log")
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("<?xml"))
        #expect(text.contains("<key>ProgramArguments</key>"))
    }
}
