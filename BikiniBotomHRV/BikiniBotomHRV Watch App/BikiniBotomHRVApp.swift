// BikiniBotomHRVApp.swift
// Bikini Bottom HRV Monitor
// M1: App Entry Point

import SwiftUI
import WatchKit

final class AppDelegate: NSObject, WKExtensionDelegate {
    func applicationDidFinishLaunching() {
        HRVManager.shared.startBackgroundMonitoring()
    }
}

@main
struct BikiniBotomHRVApp: App {
    @WKExtensionDelegateAdaptor(AppDelegate.self) private var extensionDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(hrvManager: .shared)
        }
    }
}
