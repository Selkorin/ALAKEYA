import Foundation

// ============================================================
// Permissions.swift — policy engine: risk classification, the
// manual/auto confirm rule, and remembered rules (HANDOFF §6.2-6.3,
// DOC2 §"Правила подтверждений").
// ============================================================

enum ConfirmMode: String { case manual, auto }

enum Decision: String { case once, always, deny }

final class PolicyEngine {
    static let shared = PolicyEngine()

    private(set) var rememberedRules: Set<String>
    var mode: ConfirmMode = .manual

    private init() {
        rememberedRules = Store.shared.loadRules()
    }

    func classifyRisk(_ action: Action) -> RiskLevel { action.type.risk }

    /// HANDOFF §6.3 — hard limits always ask; remembered rules auto-pass;
    /// in auto mode only low risk auto-confirms.
    func shouldAutoConfirm(_ action: Action) -> Bool {
        switch action.type {
        case .sendEmail, .deleteFile, .makePayment:
            return false // hard limits, regardless of mode
        default:
            break
        }
        if rememberedRules.contains(ruleKey(action)) { return true }
        if mode == .manual { return false }
        return action.risk == .low
    }

    func remember(_ action: Action) {
        rememberedRules.insert(ruleKey(action))
        Store.shared.saveRules(rememberedRules)
    }

    func ruleKey(_ action: Action) -> String { "\(action.type.rawValue):\(action.target)" }
}
