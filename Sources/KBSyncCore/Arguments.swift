import Foundation

public let version = "0.2.1"

public struct SyncOptions: Equatable {
    public var curve = Curve()
    public var fadeMilliseconds = 250
    /// Leave "Adjust keyboard brightness in low light" alone instead of turning it off.
    public var keepAutoBrightness = false
    public var verbose = false
    /// The flags as the user typed them, so `install` can pass them on to the launch agent.
    public var flags: [String] = []

    public init() {}
}

public enum Command: Equatable {
    case run(SyncOptions)
    case status(SyncOptions)
    case install(SyncOptions)
    case uninstall
    case help
    case version
}

public struct UsageError: Error, Equatable, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

public enum CommandParser {
    public static func parse(_ arguments: [String]) throws -> Command {
        guard let command = arguments.first else { return .help }
        let rest = Array(arguments.dropFirst())
        switch command {
        case "run": return .run(try parseOptions(rest))
        case "status": return .status(try parseOptions(rest))
        case "install": return .install(try parseOptions(rest))
        case "uninstall":
            guard rest.isEmpty else { throw UsageError("uninstall takes no options") }
            return .uninstall
        case "help", "-h", "--help": return .help
        case "version", "--version": return .version
        default: throw UsageError("unknown command '\(command)'")
        }
    }

    static func parseOptions(_ arguments: [String]) throws -> SyncOptions {
        var options = SyncOptions()
        var remaining = arguments[...]

        func number(after flag: String) throws -> Double {
            guard let text = remaining.popFirst(), let value = Double(text), value.isFinite else {
                throw UsageError("\(flag) needs a number")
            }
            return value
        }

        func percent(after flag: String) throws -> Double {
            let value = try number(after: flag)
            guard (0...100).contains(value) else { throw UsageError("\(flag) must be between 0 and 100") }
            return value / 100
        }

        while let flag = remaining.popFirst() {
            switch flag {
            case "--min":
                options.curve.minimum = try percent(after: flag)
            case "--max":
                options.curve.maximum = try percent(after: flag)
            case "--gamma":
                let gamma = try number(after: flag)
                guard gamma > 0, gamma <= 10 else { throw UsageError("--gamma must be above 0 and at most 10") }
                options.curve.gamma = gamma
            case "--fade":
                let fade = try number(after: flag)
                guard (0...10_000).contains(fade), fade.rounded() == fade else {
                    throw UsageError("--fade must be a whole number of milliseconds from 0 to 10000")
                }
                options.fadeMilliseconds = Int(fade)
            case "--keep-auto":
                options.keepAutoBrightness = true
            case "-v", "--verbose":
                options.verbose = true
            default:
                throw UsageError("unknown option '\(flag)'")
            }
        }

        guard options.curve.minimum <= options.curve.maximum else {
            throw UsageError("--min can't be higher than --max")
        }
        options.flags = arguments
        return options
    }
}
