import Foundation

enum AIProviderKind: String, Codable, CaseIterable, Identifiable {
    case openAI
    case anthropic
    case openRouter
    case routeLLM
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .openRouter: return "OpenRouter"
        case .routeLLM: return "RouteLLM"
        case .custom: return "Custom Provider"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-sonnet-latest"
        case .openRouter: return "openai/gpt-4o-mini"
        case .routeLLM: return "auto-route"
        case .custom: return ""
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .routeLLM: return "http://127.0.0.1:8000"
        case .custom: return ""
        }
    }
}

struct AIProviderConfiguration: Codable, Identifiable, Equatable {
    var id: String
    var kind: AIProviderKind
    var displayName: String
    var baseURL: String
    var modelName: String

    static func builtIn(_ kind: AIProviderKind) -> AIProviderConfiguration {
        AIProviderConfiguration(
            id: kind.rawValue,
            kind: kind,
            displayName: kind.title,
            baseURL: kind.defaultBaseURL,
            modelName: kind.defaultModel
        )
    }

    static let defaults: [AIProviderConfiguration] = [
        .builtIn(.openAI),
        .builtIn(.anthropic),
        .builtIn(.openRouter),
        .builtIn(.routeLLM),
        .builtIn(.custom),
    ]
}

enum AIClientError: LocalizedError {
    case providerNotSelected
    case apiKeyMissing
    case modelMissing
    case invalidBaseURL
    case invalidAPIKey
    case rateLimited
    case server(status: Int, message: String)
    case invalidResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .providerNotSelected:
            return "AI provider не выбран."
        case .apiKeyMissing:
            return "API key не добавлен. Откройте Settings → Models."
        case .modelMissing:
            return "Model name не указан."
        case .invalidBaseURL:
            return "Base URL провайдера указан неверно."
        case .invalidAPIKey:
            return "API key недействителен."
        case .rateLimited:
            return "Превышен лимит запросов. Попробуйте позже."
        case let .server(status, message):
            return message.isEmpty ? "Provider вернул ошибку HTTP \(status)." : message
        case .invalidResponse:
            return "Provider вернул ответ в неизвестном формате."
        case let .network(message):
            return "Ошибка сети: \(message)"
        }
    }
}

protocol AIProviderClient {
    func sendMessage(userText: String, history: [ChatMessage]) async throws -> String
    func sendMessageWithImages(userText: String, images: [Data], history: [ChatMessage]) async throws -> String
    func sendWithTools(userText: String, history: [ChatMessage], tools: [[String: Any]]) async throws -> AIProviderResponse
    func sendWithToolResults(context: Any, results: [ToolCallResult], tools: [[String: Any]]) async throws -> AIProviderResponse
}

extension AIProviderClient {
    func sendMessageWithImages(userText: String, images: [Data], history: [ChatMessage]) async throws -> String {
        try await sendMessage(userText: userText, history: history)
    }
    func sendWithTools(userText: String, history: [ChatMessage], tools: [[String: Any]]) async throws -> AIProviderResponse {
        .text(try await sendMessage(userText: userText, history: history))
    }
    func sendWithToolResults(context: Any, results: [ToolCallResult], tools: [[String: Any]]) async throws -> AIProviderResponse {
        let summary = results.map { "\($0.toolName): \($0.output)" }.joined(separator: "\n")
        return .text(summary)
    }
}

extension AIProviderConfiguration {
    var supportsVision: Bool {
        switch kind {
        case .openAI:
            let m = modelName.lowercased()
            return m.contains("gpt-4o") || m.contains("gpt-4-turbo") || m.contains("gpt-4-vision")
        case .anthropic:
            let m = modelName.lowercased()
            return m.hasPrefix("claude-3") || m.contains("claude-opus") || m.contains("claude-sonnet") || m.contains("claude-haiku")
        case .routeLLM, .openRouter, .custom:
            return false
        }
    }
}

// ── Tool calling types ────────────────────────────────

struct AIToolCall {
    let id: String
    let name: String
    let args: [String: String]
}

struct ToolCallResult {
    let callID: String
    let toolName: String
    let output: String
    let imageBase64JPEG: String?

    init(callID: String, toolName: String, output: String, imageBase64JPEG: String? = nil) {
        self.callID = callID
        self.toolName = toolName
        self.output = output
        self.imageBase64JPEG = imageBase64JPEG
    }
}

enum AIProviderResponse {
    case text(String)
    case toolCalls([AIToolCall], context: Any)
}
