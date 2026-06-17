import Foundation

// ============================================================
// Action.swift — strictly typed action plan (DOC2: model proposes
// typed tool calls, the app executes them through the policy gate).
// ============================================================

enum RiskLevel: String { case low, medium, high }

enum ActionType: String, Codable {
    // low
    case readScreen   = "read_screen"
    case screenshot
    case search
    // medium
    case openApp      = "open_app"
    case navigateURL  = "navigate_url"
    case typeText     = "type_text"
    case clickElement = "click_element"
    case appleScript  = "apple_script"
    // high
    case sendMessage  = "send_message"
    case sendEmail    = "send_email"
    case deleteFile   = "delete_file"
    case runShell     = "run_shell"
    case makePayment  = "make_payment"

    var risk: RiskLevel {
        switch self {
        case .sendMessage, .sendEmail, .deleteFile, .runShell, .makePayment:
            return .high
        case .openApp, .navigateURL, .typeText, .clickElement, .appleScript:
            return .medium
        default:
            return .low
        }
    }
}

/// A single typed action, ready for execution and for the PermissionCard.
struct Action: Identifiable {
    let id: String
    let type: ActionType
    var title: String
    var description: String
    var target: String
    var scope: String
    var reversible: Bool
    var code: String?            // shell preview, etc.
    var args: [String: String]   // executor parameters (text, app, url, query…)

    var risk: RiskLevel { type.risk }

    init(id: String = UUID().uuidString,
         type: ActionType,
         title: String,
         description: String,
         target: String,
         scope: String,
         reversible: Bool = true,
         code: String? = nil,
         args: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.target = target
        self.scope = scope
        self.reversible = reversible
        self.code = code
        self.args = args
    }
}

/// A raw tool call produced by the orchestrator before UI enrichment.
struct ToolCall {
    let name: ActionType
    let args: [String: String]
}

/// A planned task: visible steps, the typed calls, and a spoken reply.
struct Plan {
    var steps: [TaskStep]
    var toolCalls: [ToolCall]
    var reply: String
}

struct TaskStep: Identifiable {
    let id = UUID()
    var label: String
    var status: StepStatus = .pending
}

enum StepStatus: String { case pending, active, done, blocked }
