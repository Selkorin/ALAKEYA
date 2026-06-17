import SwiftUI
import AppKit

// ============================================================
// RootView.swift — composes the overlay (App.jsx equivalent). Shows one
// primary surface at a time so the auto-sizing window fits its content;
// the error toast can ride alongside the corner cluster.
// ============================================================

struct RootView: View {
    @ObservedObject var store: AgentStore
    let runner: ToolRunner
    let voice: VoiceController

    var body: some View {
        Group {
            if !store.onboarded {
                OnboardingView(onComplete: { store.completeOnboarding($0) }, onSkip: { store.completeOnboarding(.init()) })
            } else if store.showSettings {
                SettingsView(store: store, onClose: { store.showSettings = false })
            } else if store.showActivity {
                ActivityLogView(entries: store.activity, onExport: exportCSV, onClose: { store.showActivity = false })
            } else if let pending = store.pending {
                PermissionCardView(
                    action: pending.action,
                    onAllowOnce: { runner.resolvePending(.once) },
                    onAlwaysAllow: { runner.resolvePending(.always) },
                    onCancel: { runner.resolvePending(.deny) })
            } else {
                cornerCluster
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var cornerCluster: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if let err = store.error {
                ErrorToastView(message: err.message, blocked: err.blocked,
                               onDismiss: { store.error = nil },
                               onOpenSettings: { store.error = nil; store.showSettings = true })
            }
            if store.panelOpen {
                AssistantPanelView(
                    store: store,
                    onSubmit: { runner.runTask($0) },
                    onVoiceStart: { voice.start() },
                    onVoiceStop: { voice.stop() },
                    onQuick: handleQuick)
            } else {
                OrbView(state: store.orbState, size: 72) { store.panelOpen = true }
                    .padding(8)
            }
        }
        .padding(16)
    }

    private func handleQuick(_ id: String) {
        if id == "settings" { store.showSettings = true; return }
        let prompts: [String: String] = [
            "open": "Открой ", "search": "Найди в браузере: ", "summarize": "Что на этом экране?",
            "write": "Напиши ", "organize": "Открой Finder", "image": "Сгенерируй картинку: ",
            "translate": "Переведи на английский: ",
        ]
        if let p = prompts[id] { runner.runTask(p) }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "alakeya-activity.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.exportCSV().data(using: .utf8)?.write(to: url)
        }
    }
}
