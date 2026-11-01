import AppKit
import SwiftUI

@main
struct KBSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppDelegate.showIconKey) private var showIcon = true

    var body: some Scene {
        MenuBarExtra(isInserted: $showIcon) {
            MenuView(model: appDelegate.model, showIcon: $showIcon)
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Image(nsImage: MenuBarIcon.image(on: model.isOn))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let showIconKey = "showMenuBarIcon"
    let model = AppModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Opening the app by hand is how people get a hidden icon back;
        // starting at login keeps it hidden.
        if !launchedAsLoginItem() {
            UserDefaults.standard.set(true, forKey: Self.showIconKey)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        UserDefaults.standard.set(true, forKey: Self.showIconKey)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventID == kAEOpenApplication else {
            return false
        }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
