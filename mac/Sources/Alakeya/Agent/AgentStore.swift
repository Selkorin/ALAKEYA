import SwiftUI
import Combine

// ============================================================
// AgentStore.swift — the renderer-facing ObservableObject. Mirrors
// the Electron App.jsx state: status, transcript, current task,
// pending approval, error toast, activity log. SwiftUI views observe it.
// ============================================================

struct PendingApproval: Identifiable {
    let id: String
    let action: Action
    let resolve: (Decision) -> Void
}

struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
    let blocked: Bool
}

struct CurrentTask {
    var title: String
    var steps: [TaskStep]
}

@MainActor
final class AgentStore: ObservableObject {
    @Published var status: AgentStatusLabel = .ready
    @Published var panelOpen = false
    @Published var transcript = ""
    @Published var task: CurrentTask?
    @Published var pending: PendingApproval?
    @Published var error: ErrorMessage?
    @Published var activity: [ActivityEntry] = []
    @Published var showSettings = false
    @Published var showActivity = false
    @Published var settings = Settings.load()
    @Published var onboarded = UserDefaults.standard.bool(forKey: "alakeya.onboarded")

    var orbState: OrbState { status.orbState }

    init() {
        activity = Store.shared.loadActivity()
        PolicyEngine.shared.mode = settings.automation.autoSafe ? .auto : .manual
    }

    // ── mutations used by the agent runtime ───────────────
    func setStatus(_ s: AgentStatusLabel) { status = s }

    func log(_ entry: ActivityEntry) {
        activity.append(entry)
        Store.shared.saveActivity(activity)
    }

    func showError(_ message: String, blocked: Bool) {
        error = ErrorMessage(message: message, blocked: blocked)
    }

    func completeOnboarding(_ collected: OnboardingResult) {
        if let accent = collected.accent { settings.appearance.accentHex = accent }
        settings.save()
        UserDefaults.standard.set(true, forKey: "alakeya.onboarded")
        onboarded = true
    }

    func exportCSV() -> String {
        let header = "time,kind,title,subtitle,status\n"
        let df = ISO8601DateFormatter()
        let body = activity.map { e in
            [df.string(from: e.time), e.kind, e.title, e.subtitle, e.status]
                .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: ",")
        }.joined(separator: "\n")
        return header + body
    }
}
