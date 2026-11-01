import Foundation
import KBSyncCore

/// The KeyboardBrightnessClient methods kbsync calls. The class lives in the
/// private CoreBrightness framework, so it is looked up at runtime and these
/// selectors are checked before use.
@objc private protocol KeyboardBrightnessClientAPI {
    func copyKeyboardBacklightIDs() -> NSArray?
    func isKeyboardBuiltIn(_ id: UInt64) -> Bool
    func brightness(forKeyboard id: UInt64) -> Float
    func setBrightness(_ value: Float, fadeSpeed: Int32, commit: Bool, forKeyboard id: UInt64) -> Bool
    func isBacklightDimmed(onKeyboard id: UInt64) -> Bool
    func isAutoBrightnessEnabled(forKeyboard id: UInt64) -> Bool
    func enableAutoBrightness(_ enabled: Bool, forKeyboard id: UInt64) -> Bool
    func idleDimTime(forKeyboard id: UInt64) -> Double
    func registerNotificationForKeys(_ keys: NSArray, keyboardID: UInt64, block: @escaping (AnyObject?, AnyObject?) -> Void)
}

final class BuiltInKeyboard: KeyboardBacklight {
    private static let selectors = [
        "copyKeyboardBacklightIDs",
        "isKeyboardBuiltIn:",
        "brightnessForKeyboard:",
        "setBrightness:fadeSpeed:commit:forKeyboard:",
        "isBacklightDimmedOnKeyboard:",
        "isAutoBrightnessEnabledForKeyboard:",
        "enableAutoBrightness:forKeyboard:",
        "idleDimTimeForKeyboard:",
        "registerNotificationForKeys:keyboardID:block:",
    ]

    /// Held so the client outlives every call made through `client`.
    private let object: NSObject
    private let client: KeyboardBrightnessClientAPI
    private let id: UInt64

    init() throws {
        let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
        guard dlopen(path, RTLD_NOW) != nil else { throw BridgeError.missingFramework("CoreBrightness") }
        guard let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            throw BridgeError.missingSymbol("KeyboardBrightnessClient")
        }
        let object = type.init()
        for selector in Self.selectors where !object.responds(to: NSSelectorFromString(selector)) {
            throw BridgeError.missingSymbol("-[KeyboardBrightnessClient \(selector)]")
        }
        let client = unsafeBitCast(object, to: KeyboardBrightnessClientAPI.self)
        let ids = (client.copyKeyboardBacklightIDs() as? [NSNumber] ?? []).map(\.uint64Value)
        guard let id = ids.first(where: { client.isKeyboardBuiltIn($0) }) ?? ids.first else {
            throw BridgeError.noKeyboard
        }
        self.object = object
        self.client = client
        self.id = id
    }

    func brightness() -> Double? {
        Double(client.brightness(forKeyboard: id))
    }

    /// Only the idle flag counts. CoreBrightness also reports the backlight as
    /// suppressed whenever its level is 0%, and a write lights it straight back
    /// up, so treating suppressed as asleep would leave it dark for good.
    func isIdleDimmed() -> Bool {
        client.isBacklightDimmed(onKeyboard: id)
    }

    func setBrightness(_ value: Double, fadeMilliseconds: Int) -> Bool {
        client.setBrightness(Float(value), fadeSpeed: Int32(fadeMilliseconds), commit: true, forKeyboard: id)
    }

    func isAutoBrightnessEnabled() -> Bool {
        client.isAutoBrightnessEnabled(forKeyboard: id)
    }

    func setAutoBrightnessEnabled(_ enabled: Bool) -> Bool {
        client.enableAutoBrightness(enabled, forKeyboard: id)
    }

    /// "Turn keyboard backlight off after inactivity", in seconds; 0 means never.
    func idleDimSeconds() -> Double {
        client.idleDimTime(forKeyboard: id)
    }

    /// Calls `handler` on the main queue when macOS switches the backlight off
    /// or on by itself (inactivity, lid, display sleep, a 0% level).
    func observeSleep(_ handler: @escaping () -> Void) {
        let keys = ["KeyboardBacklightIdleDimActive", "KeyboardBacklightSuppressed"] as NSArray
        client.registerNotificationForKeys(keys, keyboardID: id) { _, _ in
            DispatchQueue.main.async(execute: handler)
        }
    }
}
