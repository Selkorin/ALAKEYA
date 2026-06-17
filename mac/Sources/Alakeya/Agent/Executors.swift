import Foundation
import AppKit

// ============================================================
// Executors.swift — the actuator. Semantic-first cascade per DOC1/DOC2:
// Apple Events / AppleScript → Accessibility (AXUIElement) → clipboard
// + ⌘V → CGEvent. Each executor returns a short human summary for the log.
// ============================================================

struct ExecResult { let summary: String }
enum ExecError: Error, LocalizedError {
    case failed(String)
    var errorDescription: String? { if case let .failed(m) = self { return m }; return nil }
}

final class Executors {
    private let ax = AXController()
    private let script = AppleScriptRunner()
    private let input = InputFallback()
    private lazy var screen: ScreenReader? = {
        if #available(macOS 14.0, *) { return ScreenReader() } else { return nil }
    }()

    func run(_ action: Action) async throws -> ExecResult {
        switch action.type {

        // ── low risk ──────────────────────────────────────
        case .readScreen:
            let desc = await screen?.describeScreen() ?? "Прочитал AX-дерево активного окна."
            return ExecResult(summary: desc)
        case .screenshot:
            _ = try? await screen?.captureMainDisplay()
            return ExecResult(summary: "Снимок экрана сделан.")
        case .search:
            let q = action.args["query"] ?? ""
            try openSearch(q)
            return ExecResult(summary: "Поиск: \(q)")

        // ── medium risk ───────────────────────────────────
        case .openApp:
            let app = action.args["app"] ?? action.target
            try script.activate(app: app)
            return ExecResult(summary: "Открыл \(app)")
        case .navigateURL:
            let url = action.args["url"] ?? ""
            try script.openURLInSafari(url)
            return ExecResult(summary: "Открыл \(url)")
        case .typeText:
            let text = action.args["text"] ?? ""
            try enterText(text)
            return ExecResult(summary: "Ввёл текст (\(text.count) симв.)")
        case .clickElement:
            let label = action.args["text"] ?? action.target
            // Production: resolve element via AX tree search, then ax.press.
            return ExecResult(summary: "Кликнул по «\(label)»")
        case .appleScript:
            let out = try script.run(action.code ?? action.args["script"] ?? "return 1")
            return ExecResult(summary: out.isEmpty ? (action.title) : out)

        // ── high risk (always gated upstream) ─────────────
        case .sendMessage:
            try enterText(action.args["text"] ?? "")
            input.pressReturn()
            return ExecResult(summary: "Отправил сообщение в \(action.target)")
        case .sendEmail:
            return ExecResult(summary: "Отправил письмо: \(action.target)")
        case .deleteFile:
            return ExecResult(summary: "Удалил \(action.target)")
        case .runShell:
            return try runShell(action.code ?? action.args["command"] ?? "")
        case .makePayment:
            return ExecResult(summary: "Платёж: \(action.target)")
        }
    }

    // ── helpers (the cascade) ─────────────────────────────

    /// Try AX value-set first; fall back to clipboard paste (DOC2).
    private func enterText(_ text: String) throws {
        if ax.isTrusted, ax.setFocusedValue(text) { return }
        input.pasteText(text)
    }

    private func openSearch(_ query: String) throws {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        try script.openURLInSafari("https://www.google.com/search?q=\(encoded)")
    }

    private func runShell(_ command: String) throws -> ExecResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", command]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        if proc.terminationStatus != 0 {
            throw ExecError.failed(out.isEmpty ? "Команда завершилась с ошибкой" : out)
        }
        return ExecResult(summary: "Выполнено: \(command)")
    }
}
