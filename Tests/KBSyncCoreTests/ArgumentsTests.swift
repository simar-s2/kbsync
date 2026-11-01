import Testing
@testable import KBSyncCore

@Suite struct ArgumentsTests {
    private func options(_ arguments: String...) throws -> SyncOptions {
        guard case .run(let options) = try CommandParser.parse(["run"] + arguments) else {
            Issue.record("expected a run command")
            return SyncOptions()
        }
        return options
    }

    @Test func noArgumentsShowsHelp() throws {
        #expect(try CommandParser.parse([]) == .help)
        #expect(try CommandParser.parse(["--help"]) == .help)
        #expect(try CommandParser.parse(["-h"]) == .help)
        #expect(try CommandParser.parse(["--version"]) == .version)
    }

    @Test func defaults() throws {
        let parsed = try options()
        #expect(parsed.curve == Curve())
        #expect(parsed.fadeMilliseconds == 250)
        #expect(!parsed.keepAutoBrightness)
        #expect(!parsed.verbose)
    }

    @Test func everyOption() throws {
        let parsed = try options("--min", "5", "--max", "80", "--gamma", "1.5", "--fade", "0", "--keep-auto", "-v")
        #expect(parsed.curve == Curve(minimum: 0.05, maximum: 0.8, gamma: 1.5))
        #expect(parsed.fadeMilliseconds == 0)
        #expect(parsed.keepAutoBrightness)
        #expect(parsed.verbose)
    }

    @Test func flagsAreKeptForTheLaunchAgent() throws {
        guard case .install(let parsed) = try CommandParser.parse(["install", "--max", "60", "--verbose"]) else {
            Issue.record("expected an install command")
            return
        }
        #expect(parsed.flags == ["--max", "60", "--verbose"])
        #expect(parsed.curve.maximum == 0.6)
    }

    @Test func statusAcceptsTheCurveOptions() throws {
        guard case .status(let parsed) = try CommandParser.parse(["status", "--gamma", "2"]) else {
            Issue.record("expected a status command")
            return
        }
        #expect(parsed.curve.gamma == 2)
    }

    @Test(arguments: [
        (["run", "--min"], "--min needs a number"),
        (["run", "--max", "lots"], "--max needs a number"),
        (["run", "--max", "101"], "--max must be between 0 and 100"),
        (["run", "--min", "-1"], "--min must be between 0 and 100"),
        (["run", "--min", "70", "--max", "30"], "--min can't be higher than --max"),
        (["run", "--gamma", "0"], "--gamma must be above 0 and at most 10"),
        (["run", "--gamma", "nan"], "--gamma needs a number"),
        (["run", "--fade", "1.5"], "--fade must be a whole number of milliseconds from 0 to 10000"),
        (["run", "--fade", "20000"], "--fade must be a whole number of milliseconds from 0 to 10000"),
        (["run", "--brightness", "5"], "unknown option '--brightness'"),
        (["uninstall", "-v"], "uninstall takes no options"),
        (["sync"], "unknown command 'sync'"),
    ])
    func rejectsBadInput(arguments: [String], message: String) {
        #expect(throws: UsageError(message)) { try CommandParser.parse(arguments) }
    }
}
