import CoreGraphics
import Foundation
import KBSyncCore

/// The built-in display, through the private DisplayServices framework. Its
/// brightness-change notification is system wide: it fires for the brightness
/// keys, Control Center, the ambient light sensor and other apps alike.
final class BuiltInDisplay: DisplayBrightness {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Register = @convention(c) (CGDirectDisplayID, CGDirectDisplayID, CFNotificationCallback) -> Int32
    private typealias Unregister = @convention(c) (CGDirectDisplayID, CGDirectDisplayID) -> Int32

    private let getBrightness: GetBrightness
    private let register: Register
    private let unregister: Unregister
    private var observedID: CGDirectDisplayID?

    /// The notification callback is a C function and can't capture context, so
    /// the handler lives here. There is only ever one display being followed.
    private static var onChange: (() -> Void)?

    init() throws {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_NOW) else { throw BridgeError.missingFramework("DisplayServices") }
        func symbol<T>(_ name: String, as type: T.Type) throws -> T {
            guard let pointer = dlsym(handle, name) else { throw BridgeError.missingSymbol(name) }
            return unsafeBitCast(pointer, to: type)
        }
        getBrightness = try symbol("DisplayServicesGetBrightness", as: GetBrightness.self)
        register = try symbol("DisplayServicesRegisterForBrightnessChangeNotifications", as: Register.self)
        unregister = try symbol("DisplayServicesUnregisterForBrightnessChangeNotifications", as: Unregister.self)
    }

    /// The built-in panel's ID, or nil while it is offline (lid closed with an external display).
    static func builtInID() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    func brightness() -> Double? {
        guard let id = Self.builtInID() else { return nil }
        var value: Float = 0
        guard getBrightness(id, &value) == 0 else { return nil }
        return Double(value)
    }

    /// Calls `handler` on the main queue after every brightness change.
    func observe(_ handler: @escaping () -> Void) {
        Self.onChange = handler
        reattach()
    }

    /// Moves the subscription to the built-in display's current ID. Called
    /// after any display reconfiguration, e.g. the lid closing or opening.
    func reattach() {
        let id = Self.builtInID()
        guard id != observedID else { return }
        if let old = observedID {
            _ = unregister(old, old)
            observedID = nil
        }
        guard let id else { return }
        let status = register(id, id) { _, _, _, _, _ in
            DispatchQueue.main.async { BuiltInDisplay.onChange?() }
        }
        if status == 0 { observedID = id }
    }
}

enum BridgeError: Error, CustomStringConvertible {
    case missingFramework(String)
    case missingSymbol(String)
    case noKeyboard
    case noDisplay

    var description: String {
        switch self {
        case .missingFramework(let name):
            return "couldn't load the \(name) framework; this macOS version may have moved it"
        case .missingSymbol(let name):
            return "\(name) is missing; this macOS version may have changed the private API kbsync relies on"
        case .noKeyboard:
            return "no backlit keyboard found"
        case .noDisplay:
            return "the built-in display isn't available (is the lid closed?)"
        }
    }
}
