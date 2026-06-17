import Foundation

// ============================================================
// ToolRunner.swift — permission gate → executor → journal, and the
// task loop that drives the 7 statuses (HANDOFF §4, integration §2/§4).
// ============================================================

@MainActor
final class ToolRunner {
    private let store: AgentStore
    private let policy = PolicyEngine.shared
    private let executors = Executors()
    private let orchestrator = Orchestrator()
    private let tts = SpeechSynthesizer()

    init(store: AgentStore) { self.store = store }

    // ── public entry points ───────────────────────────────
    func runTask(_ text: String) {
        Task { await runTaskAsync(text) }
    }

    func resolvePending(_ decision: Decision) {
        guard let pending = store.pending else { return }
        store.pending = nil
        pending.resolve(decision)
    }

    // ── the loop ──────────────────────────────────────────
    private func runTaskAsync(_ text: String) async {
        store.setStatus(.thinking)
        store.task = nil
        let plan = await orchestrator.plan(text)

        var steps = plan.steps
        let title = text.count > 48 ? String(text.prefix(48)) + "…" : text
        store.task = CurrentTask(title: title, steps: steps)

        for (i, call) in plan.toolCalls.enumerated() {
            steps[i].status = .active
            store.task = CurrentTask(title: title, steps: steps)

            let action = Self.action(from: call)
            let result = await runTool(action)
            switch result {
            case .denied:
                steps[i].status = .pending
                store.task = CurrentTask(title: title, steps: steps)
                store.setStatus(.ready)
                return
            case .failed:
                steps[i].status = .blocked
                store.task = CurrentTask(title: title, steps: steps)
                return // status/error already set in runTool
            case .ok:
                steps[i].status = .done
                store.task = CurrentTask(title: title, steps: steps)
            }
        }

        if !plan.reply.isEmpty {
            store.setStatus(.speaking)
            store.transcript = plan.reply
            if store.settings.voice.ttsEnabled {
                tts.rate = Float(0.5 * store.settings.voice.speed)
                await tts.speak(plan.reply)
            } else {
                try? await Task.sleep(nanoseconds: UInt64(min(2.2, 0.6 + Double(plan.reply.count) * 0.035) * 1_000_000_000))
            }
        }
        store.setStatus(.ready)
    }

    private enum ToolResult { case ok, denied, failed }

    private func runTool(_ action: Action) async -> ToolResult {
        if !policy.shouldAutoConfirm(action) {
            store.setStatus(.awaiting)
            log(action, action.scope, "awaiting")
            let decision = await requestApproval(action)
            switch decision {
            case .deny:
                log(action, "Отклонено", "denied")
                store.setStatus(.ready)
                return .denied
            case .always:
                policy.remember(action)
            case .once:
                break
            }
        }

        store.setStatus(.acting)
        do {
            let result = try await executors.run(action)
            log(action, result.summary, "ok")
            return .ok
        } catch {
            let message = humanize(error)
            store.setStatus(.error)
            log(action, message, "blocked")
            store.showError(message, blocked: isBlocked(error))
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if store.status == .error { store.setStatus(.ready) }
            }
            return .failed
        }
    }

    /// Suspend until the PermissionCard resolves a decision.
    private func requestApproval(_ action: Action) async -> Decision {
        await withCheckedContinuation { (cont: CheckedContinuation<Decision, Never>) in
            store.pending = PendingApproval(id: action.id, action: action) { decision in
                cont.resume(returning: decision)
            }
        }
    }

    // ── helpers ───────────────────────────────────────────
    private func log(_ action: Action, _ subtitle: String, _ status: String) {
        store.log(ActivityEntry(
            id: "log_\(Date().timeIntervalSince1970)_\(Int.random(in: 0...9999))",
            time: Date(), kind: action.type.rawValue,
            title: action.title, subtitle: subtitle, status: status))
    }

    private func humanize(_ error: Error) -> String {
        let s = error.localizedDescription
        if s.range(of: "(?i)not found|не найден", options: .regularExpression) != nil {
            return "Не нашёл нужный элемент или приложение."
        }
        return s.isEmpty ? "Что-то пошло не так." : s
    }

    private func isBlocked(_ error: Error) -> Bool {
        error.localizedDescription.range(of: "(?i)denied|blocked|permission", options: .regularExpression) != nil
    }

    // ── enrich a tool call into a UI-ready action ─────────
    static func action(from call: ToolCall) -> Action {
        let a = call.args
        switch call.name {
        case .openApp:
            let app = a["app"] ?? ""
            return Action(type: .openApp, title: "Открыть \(app)",
                          description: "Запустить приложение \(app).",
                          target: app, scope: app, reversible: true, args: a)
        case .navigateURL:
            return Action(type: .navigateURL, title: "Открыть ссылку",
                          description: "Перейти на \(a["url"] ?? "").",
                          target: "Safari", scope: "Браузер", reversible: true, args: a)
        case .search:
            return Action(type: .search, title: "Поиск",
                          description: "Найти: «\(a["query"] ?? "")».",
                          target: "Браузер", scope: "Браузер", reversible: true, args: a)
        case .typeText:
            return Action(type: .typeText, title: "Ввести текст",
                          description: "Напечатать: «\(String((a["text"] ?? "").prefix(80)))».",
                          target: a["target"] ?? "активное поле", scope: a["app"] ?? "—",
                          reversible: true, args: a)
        case .clickElement:
            return Action(type: .clickElement, title: "Нажать элемент",
                          description: "Кликнуть «\(a["text"] ?? a["target"] ?? "")».",
                          target: a["target"] ?? a["text"] ?? "", scope: a["app"] ?? "—",
                          reversible: true, args: a)
        case .sendMessage:
            return Action(type: .sendMessage, title: "Отправить сообщение",
                          description: "Отправить «\(String((a["text"] ?? "").prefix(80)))» — \(a["target"] ?? "").",
                          target: a["target"] ?? "", scope: a["app"] ?? "Мессенджер",
                          reversible: false, args: a)
        case .sendEmail:
            return Action(type: .sendEmail, title: "Отправить письмо",
                          description: "Отправить письмо: \(a["target"] ?? "").",
                          target: a["target"] ?? "", scope: "Mail", reversible: false, args: a)
        case .deleteFile:
            return Action(type: .deleteFile, title: "Удалить файл",
                          description: "Удалить \(a["target"] ?? ""). Действие необратимо.",
                          target: a["target"] ?? "", scope: "Finder", reversible: false, args: a)
        case .runShell:
            return Action(type: .runShell, title: "Выполнить shell-команду",
                          description: "Команда показана ниже. Проверь перед запуском.",
                          target: "Terminal", scope: "Система", reversible: false,
                          code: a["command"], args: a)
        case .makePayment:
            return Action(type: .makePayment, title: "Совершить платёж",
                          description: "Оплата: \(a["target"] ?? "").",
                          target: a["target"] ?? "", scope: "Платежи", reversible: false, args: a)
        case .appleScript:
            return Action(type: .appleScript, title: "AppleScript",
                          description: "Выполнить скрипт.", target: a["target"] ?? "—",
                          scope: "Система", reversible: true, code: a["script"], args: a)
        case .readScreen:
            return Action(type: .readScreen, title: "Прочитать экран",
                          description: "Осмотреть активное окно.", target: "Экран",
                          scope: "Только чтение", reversible: true, args: a)
        case .screenshot:
            return Action(type: .screenshot, title: "Снимок экрана",
                          description: "Сделать снимок для верификации.", target: "Экран",
                          scope: "Только чтение", reversible: true, args: a)
        }
    }
}
