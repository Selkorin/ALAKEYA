import SwiftUI
import AppKit

extension Notification.Name {
    static let alakeyaShowVoiceOrb = Notification.Name("alakeya.showVoiceOrb")
}

@main
struct AlakeyaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        SwiftUI.Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBar      : StatusBarController!
    private var orbController  : FloatingOrbWindowController!
    private var panelController: MainPanelWindowController!
    private var store          : AgentStore!
    private var runner         : ToolRunner!
    private var voice          : VoiceController!
    private var updateManager  : UpdateManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Check permissions on launch WITHOUT triggering prompts
        let perms = PermissionsManager.shared
        if !perms.accessibilityGranted {
            // Only show prompt if permission is missing
            _ = perms.requestAccessibility()
        }
        if !perms.screenRecordingGranted {
            // Only show prompt if permission is missing
            _ = perms.requestScreenRecording()
        }

        store  = AgentStore()
        runner = ToolRunner(store: store)
        ToolRouter.shared.register(ComputerTools())
        ToolRouter.shared.register(LocalFileTools())
        ToolRouter.shared.register(BrowserTools())
        ToolRouter.shared.register(BrowserAgentTools())
        ToolRouter.shared.register(BrowserUseTools())
        ToolRouter.shared.register(ConnectorTools())
        ToolRouter.shared.register(ResearchTools())
        ToolRouter.shared.register(DocumentTools())
        voice  = VoiceController(store: store, runner: runner)
        WAI.accent = Color(hex: store.settings.appearance.accentHex)

        updateManager = UpdateManager()
        updateManager.initialize(settings: store.settings.updates)

        panelController = MainPanelWindowController(
            store: store, runner: runner, voice: voice, updateManager: updateManager
        )
        orbController   = FloatingOrbWindowController(store: store)
        statusBar = StatusBarController()

        orbController.onOpenPanel = { [weak self] in
            self?.panelController.open()
            self?.voice.start()
        }

        NotificationCenter.default.addObserver(
            forName: .alakeyaShowVoiceOrb,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.orbController.isShown {
                    self.voice.stop()
                    self.orbController.hide()
                } else {
                    self.orbController.show()
                    self.voice.start()
                }
            }
        }

        statusBar.onToggleWidget = { [weak self] in
            self?.orbController.show()
        }

        statusBar.onOpenSettings = { [weak self] in
            self?.panelController.openWithSettings()
        }

        panelController.open()
        Task { await updateManager.checkOnLaunchIfEnabled() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        panelController.open()
        return true
    }
}
