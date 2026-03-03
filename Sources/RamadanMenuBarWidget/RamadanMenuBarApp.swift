import AppKit
import SwiftUI

@main
struct RamadanMenuBarWidgetApp: App {
    @NSApplicationDelegateAdaptor(AccessoryAppDelegate.self) private var appDelegate
    @StateObject private var store = RamadanStore()

    var body: some Scene {
        MenuBarExtra {
            RamadanPopoverView(store: store)
        } label: {
            Text(store.statusTitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AccessoryAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
