import SwiftUI
import AppKit

// ============================================================
// AlakeyaApp.swift — @main entry. Builds the agent runtime and shows
// the floating overlay. Runs as a menu-bar / accessory app (no Dock
// icon — LSUIElement, set in Info.plist), like a desktop companion.
// ============================================================

@main
struct AlakeyaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        // The visible UI lives in the borderless overlay panel created by
        // AppDelegate; this empty Settings scene keeps SwiftUI's App happy.
        // Qualified to avoid clashing with our own `Settings` model type.
        SwiftUI.Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: OrbWindowController?
    private var store: AgentStore!
    private var runner: ToolRunner!
    private var voice: VoiceController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon

        store = AgentStore()
        runner = ToolRunner(store: store)
        voice = VoiceController(store: store, runner: runner)

        // Apply saved accent.
        WAI.accent = Color(hex: store.settings.appearance.accentHex)

        let root = RootView(store: store, runner: runner, voice: voice)
        let controller = OrbWindowController(rootView: root)
        controller.show()
        self.controller = controller

        // Ask for microphone up front (DOC2 onboarding step 3).
        Task { _ = await PermissionsManager.shared.requestMicrophone() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // stay resident as an overlay companion
    }
}
