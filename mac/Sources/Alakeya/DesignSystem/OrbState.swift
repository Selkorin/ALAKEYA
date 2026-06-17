import Foundation

// ============================================================
// OrbState.swift — the 7 visual states + the status<->state map,
// ported from handoff/src/orbMachine.js.
// ============================================================

enum OrbState: String {
    case idle, listening, thinking, speaking, acting, permission, error
}

// Human-facing agent statuses (HANDOFF §4.2).
enum AgentStatusLabel: String, CaseIterable {
    case ready      = "Готов"
    case listening  = "Слушаю"
    case thinking   = "Думаю"
    case speaking   = "Говорю"
    case acting     = "Действую"
    case awaiting   = "Жду подтверждения"
    case error      = "Ошибка"

    var orbState: OrbState {
        switch self {
        case .ready:     return .idle
        case .listening: return .listening
        case .thinking:  return .thinking
        case .speaking:  return .speaking
        case .acting:    return .acting
        case .awaiting:  return .permission
        case .error:     return .error
        }
    }
}
