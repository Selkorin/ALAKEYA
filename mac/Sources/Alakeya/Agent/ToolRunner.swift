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
    private let speech = SpeechService()
    private let imageGenerator = ImageGenerationService()
    private var pendingLocalBusinessQueries: [UUID: LocalBusinessQuery] = [:]

    init(store: AgentStore) { self.store = store }

    // ── public entry points ───────────────────────────────
    func runTask(_ text: String, images: [Data] = [], sessionID: UUID, agentID: String) {
        Task { await runTaskAsync(text, images: images, sessionID: sessionID, agentID: agentID) }
    }

    func resolvePending(_ decision: Decision) {
        guard let pending = store.pending else { return }
        store.pending = nil
        pending.resolve(decision)
    }

    // ── the loop ──────────────────────────────────────────
    private func runTaskAsync(_ text: String, images: [Data], sessionID: UUID, agentID: String) async {
        store.setStatus(.thinking)
        store.setToolStatus(nil)
        store.task = nil
        let sessionHistory = store.messages(for: sessionID)

        // Resume a deterministic local-business request after the explicit
        // city/region follow-up. The original category, count and filters must
        // not be delegated back to the model or inferred a second time.
        if let pendingQuery = pendingLocalBusinessQueries[sessionID] {
            if let city = LocalBusinessQuery.parseCityContinuation(from: text) {
                pendingLocalBusinessQueries[sessionID] = nil
                await appendLocalBusinessResult(
                    pendingQuery.resolvingCity(city),
                    sessionID: sessionID
                )
                return
            }
            // A new command replaces the unfinished request.
            pendingLocalBusinessQueries[sessionID] = nil
        }

        // Handle memory commands locally — no AI call needed.
        if let response = handleMemoryCommand(text) {
            store.appendMessage(
                ChatMessage(role: .assistant, content: response),
                to: sessionID
            )
            store.setStatus(.ready)
            return
        }

        if let response = handleSocialStyleCommand(text) {
            store.appendMessage(
                ChatMessage(role: .assistant, content: response),
                to: sessionID
            )
            store.setStatus(.ready)
            return
        }

        if let contextualQuery = Self.contextualLocalBusinessQuery(for: text, history: sessionHistory) {
            await appendLocalBusinessResult(contextualQuery, sessionID: sessionID)
            return
        }

        let scope = Self.detectScope(text)

        if scope != .computer,
           await handleImageGenerationRequest(text, sessionID: sessionID, agentID: agentID) {
            return
        }

        if await handleTelegramPostRequest(text, history: sessionHistory, sessionID: sessionID, agentID: agentID) {
            return
        }

        if await handleTelegramCommand(text, history: sessionHistory, sessionID: sessionID) {
            return
        }

        do {
            let history = buildHistory(from: sessionHistory)
            let memCtx  = MemoryStore.shared.composeContext()

            let tools = ToolRouter.shared.toolSchemas(scope: scope)

            let toolNames = tools.compactMap {
                ($0["function"] as? [String: Any])?["name"] as? String
            }
            print("[AI Tools] scope=\(scope) count=\(tools.count) names=[\(toolNames.joined(separator: ", "))]")

            guard tools.count <= 64 else {
                throw AIClientError.server(
                    status: 400,
                    message: "Tool scope too broad: \(scope). Count: \(tools.count)"
                )
            }

            // ── Deterministic local business pipeline ─────────
            // Bypasses free-form agent for reliable structured extraction.
            if scope == .localBusinessResearch || scope == .localBusinessResearchThenExport {
                let query = LocalBusinessQuery.parse(from: text)
                guard query.city != nil else {
                    pendingLocalBusinessQueries[sessionID] = query
                    store.appendMessage(
                        ChatMessage(
                            role: .assistant,
                            content: "В каком городе искать \(query.category)? Укажите город или регион."
                        ),
                        to: sessionID
                    )
                    store.setStatus(.ready)
                    return
                }
                await appendLocalBusinessResult(query, sessionID: sessionID)
                return
            }

            // ── Standard path (plain gen / export / research / browser) ──
            let client = try AIClient(settings: effectiveSettings(agentID: agentID))

            // Resolve "this" → inject last meaningful content for export.
            let resolvedText = scope == .documentExport
                ? ExportInputResolver.resolve(userText: text, history: sessionHistory)
                : text

            ExportResultStore.shared.clear()

            let reply: String
            var toolStructuredTables: [ParsedMarkdownTable] = []
            if !images.isEmpty {
                let imageHistory = historyWithoutCurrentImageTurn(history, currentText: text)
                reply = try await client.sendMessageWithImages(
                    userText: resolvedText,
                    images: images,
                    history: imageHistory,
                    memoryContext: memCtx
                )
            } else if tools.isEmpty {
                reply = try await client.sendMessage(
                    userText: resolvedText, history: history, memoryContext: memCtx
                )
            } else {
                let output = try await runAgenticLoop(
                    client: client, userText: resolvedText, history: history,
                    memoryContext: memCtx, tools: tools
                )
                reply = output.reply
                toolStructuredTables = output.structuredTables
            }

            let fileAttachments = ExportResultStore.shared.drain()

            // Extract sources when the reply came from a browser or research scope.
            let sources: [SourceReference]
            switch scope {
            case .browser, .research, .browserAndConnectors, .all:
                sources = SourceExtractor.extractLinks(from: reply)
            default:
                sources = []
            }

            // Parse structured tables from reply/tool output (for "выгрузи это" export later)
            var structuredTables = MarkdownTableParser.parse(from: reply)
            structuredTables.append(contentsOf: toolStructuredTables)

            store.appendMessage(
                ChatMessage(
                    role: .assistant, content: reply,
                    sources: sources, fileAttachments: fileAttachments,
                    structuredTables: structuredTables
                ),
                to: sessionID
            )
            store.setToolStatus(nil)
            store.setStatus(.speaking)
            if store.activeSessionID == sessionID {
                store.transcript = reply
            }

            let voiceMode = store.settings.voice.voiceMode
            if voiceMode != .off, store.activeSessionID == sessionID {
                let speechText = SpeechOutputFormatter.format(reply, mode: voiceMode)
                if !speechText.isEmpty {
                    do {
                        try await speech.speak(speechText, settings: store.settings)
                    } catch {
                        store.showError(
                            "Ответ получен, но озвучивание недоступно: \(humanize(error))",
                            blocked: false
                        )
                    }
                }
            }
            store.setStatus(.ready)
        } catch {
            let message = humanize(error)
            store.setToolStatus(nil)
            store.appendMessage(
                ChatMessage(
                    role: .assistant,
                    content: "Не удалось получить ответ: \(message)"
                ),
                to: sessionID
            )
            store.setStatus(.error)
            store.showError(message, blocked: isConfigurationError(error))
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if store.status == .error { store.setStatus(.ready) }
            }
        }
        store.setToolStatus(nil)
    }

    private func appendLocalBusinessResult(
        _ query: LocalBusinessQuery,
        sessionID: UUID
    ) async {
        let result = await LocalBusinessSearchCoordinator.run(query: query, store: store)
        let structuredTables: [ParsedMarkdownTable] = result.table.map { [$0] } ?? []

        var seenURLs = Set<String>()
        let sources: [SourceReference] = result.leads.compactMap { lead in
            guard !lead.sourceURL.isEmpty else { return nil }
            guard seenURLs.insert(lead.sourceURL).inserted else { return nil }
            return SourceReference(title: lead.sourceName, url: lead.sourceURL)
        }

        store.appendMessage(
            ChatMessage(
                role: .assistant,
                content: result.formattedText,
                sources: sources,
                fileAttachments: result.fileAttachments,
                structuredTables: structuredTables
            ),
            to: sessionID
        )
        store.setToolStatus(nil)
        store.setStatus(.ready)
    }

    private func handleImageGenerationRequest(_ text: String, sessionID: UUID, agentID: String) async -> Bool {
        guard Self.looksLikeImageGenerationRequest(text) else { return false }
        let idea = Self.imageGenerationIdea(from: text)
        guard !idea.isEmpty else { return false }

        do {
            store.setStatus(.acting)
            store.setToolStatus("Генерирую изображение: \(String(idea.prefix(80)))")
            let result = try await imageGenerator.generate(
                idea: idea,
                format: .png,
                settings: effectiveSettings(agentID: agentID)
            )
            store.setToolStatus(nil)
            var content = "Готово: сгенерировала изображение."
            if let warning = result.warning, !warning.isEmpty {
                content += "\n\n\(warning)"
            }
            store.appendMessage(
                ChatMessage(
                    role: .assistant,
                    content: content,
                    images: [result.imageData],
                    fileAttachments: result.files
                ),
                to: sessionID
            )
            store.setStatus(.ready)
            return true
        } catch {
            let message = humanize(error)
            store.setToolStatus(nil)
            store.appendMessage(
                ChatMessage(role: .assistant, content: "Не удалось сгенерировать изображение: \(message)"),
                to: sessionID
            )
            store.setStatus(.ready)
            return true
        }
    }

    private func effectiveSettings(agentID: String) -> Settings {
        AgentProfileStore.shared.resolvedSettings(
            base: store.settings,
            activeAgentID: agentID
        )
    }

    private enum ToolResult { case ok, denied, failed }
    private struct AgenticRunOutput {
        var reply: String
        var structuredTables: [ParsedMarkdownTable]
    }

    // Returns status, output string, and optional image so the agentic loop can feed results back to the model.
    private func runTool(_ action: Action) async -> (ToolResult, String, String?) {
        if !policy.shouldAutoConfirm(action) {
            store.setStatus(.awaiting)
            log(action, action.scope, "awaiting")
            let decision = await requestApproval(action)
            switch decision {
            case .deny:
                log(action, "Отклонено", "denied")
                store.setStatus(.ready)
                return (.denied, "Отклонено пользователем.", nil)
            case .always:
                policy.remember(action)
            case .once:
                break
            }
        }

        store.setStatus(.acting)
        store.setToolStatus(Self.progressText(for: action))
        do {
            let result = try await executors.run(action) { [weak store] message in
                store?.setToolStatus(message)
            }
            log(action, result.summary, "ok")
            if action.type == .connectorSend {
                store.setToolStatus(nil)
            } else {
                store.setToolStatus("Собираю итоговый ответ…")
            }
            return (.ok, result.summary, result.imageBase64JPEG)
        } catch {
            let message = humanize(error)
            store.setStatus(.error)
            store.setToolStatus(nil)
            log(action, message, "blocked")
            store.showError(message, blocked: isBlocked(error))
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if store.status == .error { store.setStatus(.ready) }
            }
            return (.failed, "Ошибка: \(message)", nil)
        }
    }

    // ── Agentic loop: AI ↔ tools, bounded with repeat protection ──
    private func runAgenticLoop(
        client: AIClient,
        userText: String,
        history: [ChatMessage],
        memoryContext: String,
        tools: [[String: Any]]
    ) async throws -> AgenticRunOutput {
        var response = try await client.sendWithTools(
            userText: userText, history: history, memoryContext: memoryContext, tools: tools
        )
        var previousSignature = ""
        var repeatedRounds = 0
        var toolStructuredTables: [ParsedMarkdownTable] = []
        let maxToolRounds = tools.contains { schema in
            guard let fn = schema["function"] as? [String: Any],
                  let name = fn["name"] as? String else { return false }
            return name.hasPrefix("computer_")
        } ? 30 : 8
        for _ in 0..<maxToolRounds {
            guard case .toolCalls(let calls, let context) = response else { break }
            let signature = calls.map { call in
                let args = call.args.sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: "&")
                return "\(call.name):\(args)"
            }.joined(separator: "|")
            if signature == previousSignature {
                repeatedRounds += 1
                let readOnlyResearchRepeat = calls.allSatisfy { Self.isReadOnlyResearchTool($0.name) }
                let computerRepeat = calls.allSatisfy { $0.name.hasPrefix("computer_") }
                let maxRepeatedRounds = computerRepeat ? 8 : (readOnlyResearchRepeat ? 5 : 2)
                if repeatedRounds >= maxRepeatedRounds {
                    let reply = readOnlyResearchRepeat
                        ? "Я уже выполнила этот же поиск несколько раз и остановила повтор, чтобы не ждать лишнее. Попробуйте переформулировать запрос или попросите выгрузку — я использую уже найденные источники."
                        : computerRepeat
                            ? "Я остановила повторяющееся управление экраном, чтобы не зациклиться. Попробуйте уточнить цель или разрешите продолжить с текущего состояния."
                            : "Я остановила повторяющиеся действия, чтобы не зациклиться."
                    return AgenticRunOutput(
                        reply: reply,
                        structuredTables: toolStructuredTables
                    )
                }
            } else {
                previousSignature = signature
                repeatedRounds = 0
            }
            var results: [ToolCallResult] = []
            for call in calls {
                guard let action = ToolRouter.shared.makeAction(toolName: call.name, args: call.args)
                else {
                    results.append(ToolCallResult(
                        callID: call.id, toolName: call.name,
                        output: "Инструмент '\(call.name)' не найден."))
                    continue
                }
                let (_, summary, imageBase64JPEG) = await runTool(action)
                toolStructuredTables.append(contentsOf: Self.extractToolTables(from: summary))
                store.setStatus(.thinking)
                results.append(ToolCallResult(
                    callID: call.id,
                    toolName: call.name,
                    output: summary,
                    imageBase64JPEG: imageBase64JPEG
                ))
            }
            response = try await client.sendWithToolResults(
                context: context, results: results, tools: tools
            )
        }
        if case .text(let text) = response {
            return AgenticRunOutput(reply: text, structuredTables: toolStructuredTables)
        }
        return AgenticRunOutput(reply: "Готово.", structuredTables: toolStructuredTables)
    }

    private static func extractToolTables(from summary: String) -> [ParsedMarkdownTable] {
        guard summary.contains("EXPORT_TABLE:") || summary.contains("BROWSER_AGENT_") else {
            return []
        }
        return MarkdownTableParser.parse(from: summary).filter { !$0.rows.isEmpty }
    }

    private static func isReadOnlyResearchTool(_ toolName: String) -> Bool {
        guard let type = ActionType(rawValue: toolName) else { return false }
        switch type {
        case .searchInternet, .researchPlan, .qualityScoreResults,
             .browserAgentSearch, .browserAgentExtract,
             .browserUseSearch, .browserUseExtract, .browserUseScreenshot,
             .extractSearchResults, .extractBusinessCards, .extractHotelCards,
             .extractContactCards, .extractArticle:
            return true
        default:
            return false
        }
    }

    /// Suspend until the PermissionCard resolves a decision, with a 120 s timeout.
    private func requestApproval(_ action: Action) async -> Decision {
        await withCheckedContinuation { cont in
            var resolved = false
            let resolve: (Decision) -> Void = { decision in
                guard !resolved else { return }
                resolved = true
                self.store.pending = nil
                cont.resume(returning: decision)
            }
            store.pending = PendingApproval(id: action.id, action: action) { decision in
                resolve(decision)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                if store.pending?.id == action.id { resolve(.deny) }
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

    private static func progressText(for action: Action) -> String {
        switch action.type {
        case .searchInternet:
            let query = action.args["query"] ?? action.target
            return "Ищу в интернете без открытия браузера: \(query)"
        case .browserAgentSearch:
            let query = action.args["query"] ?? action.target
            return "Ищу и парсю найденные страницы: \(query)"
        case .browserAgentExtract:
            return "Открываю источник: \(action.args["url"] ?? action.target)"
        case .researchPlan:
            return "Планирую поисковые запросы…"
        case .qualityScoreResults:
            return "Сравниваю и ранжирую источники…"
        case .browserOpen:
            return "Открываю браузер: \(action.args["url"] ?? action.target)"
        case .connectorSend:
            if action.args["tool_name"] == "telegram_publish_post" {
                return "Публикую в Telegram: \(action.args["channel"] ?? action.target)"
            }
            return "Отправляю через коннектор…"
        default:
            return action.title
        }
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

    private func isConfigurationError(_ error: Error) -> Bool {
        guard let error = error as? AIClientError else { return false }
        switch error {
        case .providerNotSelected, .apiKeyMissing, .modelMissing, .invalidBaseURL, .invalidAPIKey:
            return true
        case .rateLimited, .server, .invalidResponse, .network:
            return false
        }
    }

    // ── history ───────────────────────────────────────────
    private static let ChatHistoryLimit = 20

    private func buildHistory(from messages: [ChatMessage]) -> [ChatMessage] {
        let recent = Array(messages.suffix(Self.ChatHistoryLimit))
        let filtered = recent.filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // Drop leading assistant messages — providers require history to start with user.
        guard let firstUser = filtered.firstIndex(where: { $0.role == .user }) else { return [] }
        return Array(filtered[firstUser...])
    }

    private func historyWithoutCurrentImageTurn(
        _ history: [ChatMessage],
        currentText: String
    ) -> [ChatMessage] {
        guard let last = history.last,
              last.role == .user,
              !last.images.isEmpty,
              last.content == currentText
        else { return history }
        return Array(history.dropLast())
    }

    private static func contextualLocalBusinessQuery(
        for text: String,
        history: [ChatMessage]
    ) -> LocalBusinessQuery? {
        let lower = text.lowercased()
        let asksForBusinessDetails = lower.range(
            of: #"(найди|покажи|дай|собери|вытащи|нужны)?.{0,20}(номер|телефон|контакт|адрес|сайт)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        guard asksForBusinessDetails else { return nil }

        let current = LocalBusinessQuery.parse(from: text)
        guard current.category == "организации" || current.city == nil else { return nil }

        for message in history.reversed() where message.role == .user {
            guard message.content != text else { continue }
            let previous = LocalBusinessQuery.parse(from: message.content)
            guard previous.category != "организации", let previousCity = previous.city else { continue }
            return LocalBusinessQuery(
                rawText: text,
                category: previous.category,
                city: previousCity,
                region: previous.region ?? previousCity,
                targetCount: current.targetCount,
                requireNoWebsite: current.requireNoWebsite,
                requirePhone: true,
                requestedSources: current.requestedSources,
                exportFormat: current.exportFormat,
                shouldExport: current.shouldExport
            )
        }
        return nil
    }

    private static func looksLikeImageGenerationRequest(_ text: String) -> Bool {
        let lower = text.lowercased()
        if looksLikeComputerControlRequest(text) { return false }

        let hasGenerateVerb = lower.range(
            of: #"(сгенерируй|сгенерировать|создай|сделай|нарисуй|изобрази|generate|draw|make)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let hasImageWord = lower.range(
            of: #"(изображени|картинк|арт|иллюстрац|фото|постер|обложк|логотип|иконк)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        if hasGenerateVerb && hasImageWord { return true }
        if hasGenerateVerb,
           lower.range(of: #"(pdf|docx|word|excel|таблиц|документ|письмо|пост|текст|код|папк|директор|файл|finder|файндер|рабоч|desktop|компьютер|экран|окн|приложени|сервис|браузер|сайт|соцсет|telegram|телеграм|почт)"#, options: [.regularExpression, .caseInsensitive]) == nil {
            return true
        }
        return false
    }

    private static func looksLikeComputerControlRequest(_ text: String) -> Bool {
        let lower = text.lowercased()
        let patterns: [String] = [
            #"(управляй|поработай|сделай|выполни).{0,45}(компьютер|экран|рабоч|окн|приложени|интерфейс)"#,
            #"(открой|запусти|перейди).{0,35}(finder|файндер|terminal|терминал|приложени|папк|файл|окн|рабоч)"#,
            #"(создай|сделай).{0,35}(папк|директор|файл).{0,45}(рабоч|desktop|finder|файндер|документ|загрузк)"#,
            #"(кликни|нажми|тапни|двойной клик|правый клик|перетащи|наведи|курсор|мыш)"#,
            #"(напечатай|введи|вставь).{0,35}(активн|поле|окн|приложени|экран)"#,
            #"(нажми|press).{0,20}(enter|tab|escape|cmd|command|ctrl|shift|⌘)"#,
            #"(сделай|получи|покажи).{0,20}(скрин|скриншот|screenshot).{0,20}(экран|компьютер|рабоч)"#,
            #"(прокрути|scroll).{0,35}(экран|окн|список|вверх|вниз)"#,
        ]
        return patterns.contains {
            lower.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func imageGenerationIdea(from text: String) -> String {
        var idea = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacements: [(String, String)] = [
            (#"(?i)^(сгенерируй|сгенерировать|создай|сделай|нарисуй|изобрази)\s+(изображение|картинку|арт|иллюстрацию|фото|постер|обложку|логотип|иконку)?\s*"#, ""),
            (#"(?i)^(generate|draw|make)\s+(an?|the)?\s*(image|picture|poster|logo|icon|illustration)?\s*"#, "")
        ]
        for (pattern, replacement) in replacements {
            idea = idea.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        idea = idea.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":—-")))
        return idea.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : idea
    }

    // ── deterministic Telegram connector command ─────────────

    private func handleTelegramPostRequest(
        _ text: String,
        history: [ChatMessage],
        sessionID: UUID,
        agentID: String
    ) async -> Bool {
        guard Self.requiresSocialContentPlanning(text),
              Self.asksToPublish(text),
              Self.looksLikeTelegramCommand(text, history: history) else { return false }

        guard ConnectorRegistry.shared.status(for: "telegram") == .connected else {
            store.appendMessage(
                ChatMessage(role: .assistant, content: "Telegram подключён не полностью. Откройте Настройки → Коннекторы → Telegram и подключите Bot Token."),
                to: sessionID
            )
            store.setStatus(.ready)
            return true
        }

        let explicitChannel = Self.extractTelegramChannel(from: text)
        let channels: [String]
        if let explicitChannel {
            channels = [explicitChannel]
        } else {
            channels = SocialPublishingTargetStore.shared.selectedTargets()
                .filter { $0.connectorID == "telegram" }
                .map { $0.destination }
        }
        guard !channels.isEmpty else {
            store.appendMessage(
                ChatMessage(role: .assistant, content: "Закрепите Telegram-группу через + → Соц.сети или укажите @username/chat_id в сообщении."),
                to: sessionID
            )
            store.setStatus(.ready)
            return true
        }

        do {
            store.setStatus(.thinking)
            store.setToolStatus("Пишу пост для Telegram…")
            let client = try AIClient(settings: effectiveSettings(agentID: agentID))
            let prompt = """
            Напиши готовый Telegram-пост по запросу пользователя.
            Запрос: \(text)

            Требования:
            - не повторяй команду пользователя;
            - дай готовый текст публикации;
            - используй Telegram HTML-разметку: <b>заголовок</b>, <i>описание/настроение</i>, <blockquote>цитата или ключевая мысль</blockquote>;
            - длинные списки, факты, рецепты и плотные объяснения помещай в <blockquote expandable>...</blockquote>;
            - если есть секция “Факты:” или “Вот факты:”, сделай ее <b>Факты:</b>, а пункты ниже помести в quote block;
            - ссылки оформляй как <a href="https://...">текст ссылки</a>;
            - custom emoji используй только при наличии emoji-id: <tg-emoji emoji-id="...">🙂</tg-emoji>; если ID нет, используй обычные, но не дефолтные однообразные эмодзи, а точные по смыслу;
            - не используй Markdown-маркеры **, ###, ``` и не пиши "Вот пост:";
            - короткий цепляющий первый абзац;
            - раздели текст на смысловые блоки;
            - эмодзи только тематические и умеренно;
            - 1 CTA;
            - 3-6 релевантных хэштегов;
            - стиль живой, человеческий, как у опытного Telegram-копирайтера.
            """
            let post = try await client.sendMessage(
                userText: prompt,
                history: buildHistory(from: history),
                memoryContext: MemoryStore.shared.composeContext()
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !post.isEmpty else {
                store.setToolStatus(nil)
                store.appendMessage(ChatMessage(role: .assistant, content: "Не получилось сформировать текст поста."), to: sessionID)
                store.setStatus(.ready)
                return true
            }

            var summaries: [String] = []
            for channel in channels {
                let action = Action(
                    type: .connectorSend,
                    title: "Опубликовать в Telegram",
                    description: "Отправить готовый пост в \(channel).",
                    target: channel,
                    scope: "Telegram",
                    reversible: false,
                    args: [
                        "tool_name": "telegram_publish_post",
                        "channel": channel,
                        "text": post,
                        "parse_mode": "HTML"
                    ]
                )
                let (result, summary, _) = await runTool(action)
                switch result {
                case .ok, .failed:
                    summaries.append(summary)
                case .denied:
                    summaries.append("Отправка в \(channel) отменена.")
                }
            }
            store.setToolStatus(nil)
            let response = ([post, ""] + summaries).joined(separator: "\n")
            store.appendMessage(ChatMessage(role: .assistant, content: response), to: sessionID)
            store.setStatus(.ready)
            return true
        } catch {
            let message = humanize(error)
            store.setToolStatus(nil)
            store.appendMessage(ChatMessage(role: .assistant, content: "Не удалось подготовить публикацию: \(message)"), to: sessionID)
            store.setStatus(.ready)
            return true
        }
    }

    private func handleTelegramCommand(_ text: String, history: [ChatMessage], sessionID: UUID) async -> Bool {
        guard Self.looksLikeTelegramCommand(text, history: history) else { return false }
        guard !Self.requiresSocialContentPlanning(text) else { return false }

        guard ConnectorRegistry.shared.status(for: "telegram") == .connected else {
            store.appendMessage(
                ChatMessage(role: .assistant, content: "Telegram подключён не полностью. Откройте Настройки → Коннекторы → Telegram и подключите Bot Token."),
                to: sessionID
            )
            store.setStatus(.ready)
            return true
        }

        let explicitChannel = Self.extractTelegramChannel(from: text)
        let channels: [String]
        if let explicitChannel {
            channels = [explicitChannel]
        } else {
            channels = SocialPublishingTargetStore.shared.selectedTargets()
                .filter { $0.connectorID == "telegram" }
                .map { $0.destination }
        }
        let message = Self.extractTelegramMessage(from: text)
            ?? Self.extractRecentAssistantDraft(from: history, currentText: text)
            ?? Self.extractRecentTelegramMessage(from: history)

        guard let message, !message.isEmpty else {
            store.appendMessage(
                ChatMessage(role: .assistant, content: "Что отправить в Telegram? Напишите текст сообщения."),
                to: sessionID
            )
            store.setStatus(.ready)
            return true
        }

        guard !channels.isEmpty else {
            store.appendMessage(
                ChatMessage(role: .assistant, content: "В какой Telegram-канал или группу отправить? Укажите username вроде @wai_marketing, chat_id или закрепите цель через + → Соц.сети."),
                to: sessionID
            )
            store.setStatus(.ready)
            return true
        }

        var summaries: [String] = []
        for channel in channels {
            let action = Action(
                type: .connectorSend,
                title: "Опубликовать в Telegram",
                description: "Отправить «\(String(message.prefix(80)))» в \(channel).",
                target: channel,
                scope: "Telegram",
                reversible: false,
                args: [
                    "tool_name": "telegram_publish_post",
                    "channel": channel,
                    "text": message,
                    "parse_mode": Self.telegramParseMode(for: message)
                ]
            )

            let (result, summary, _) = await runTool(action)
            switch result {
            case .ok, .failed:
                summaries.append(summary)
            case .denied:
                summaries.append("Отправка в \(channel) отменена.")
            }
        }
        store.setToolStatus(nil)
        store.appendMessage(ChatMessage(role: .assistant, content: summaries.joined(separator: "\n")), to: sessionID)
        store.setStatus(.ready)
        return true
    }

    private static func looksLikeTelegramCommand(_ text: String, history: [ChatMessage]) -> Bool {
        let lower = text.lowercased()
        if lower.range(of: #"(telegram|телеграм|телеграмм|тг|активные соцсети)"#, options: [.regularExpression, .caseInsensitive]) != nil,
           lower.range(of: #"(отправь|отправляй|напиши|пошли|опубликуй|публикуй|запости|сообщен|пост|групп|канал)"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        if extractTelegramChannel(from: text) != nil {
            return extractRecentTelegramMessage(from: history) != nil
        }
        return false
    }

    private static func requiresSocialContentPlanning(_ text: String) -> Bool {
        let lower = text.lowercased()
        let hasPlanningSignal = lower.range(
            of: #"(smm|смм|маркетинг|копирайт|контент|контент-план|подготовь|создай|сгенерируй|напиши\s+пост|пост\s+про|публикаци[яю]\s+про|разные\s+пост|для\s+кажд|стиль\s+групп|хэштег|cta)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        return hasPlanningSignal || (
            asksToPublish(text)
            && lower.range(of: #"\bпост\b"#, options: [.regularExpression, .caseInsensitive]) != nil
            && lower.range(of: #"(про|о\s+|на\s+тему)"#, options: [.regularExpression, .caseInsensitive]) != nil
        )
    }

    private static func asksToPublish(_ text: String) -> Bool {
        text.lowercased().range(
            of: #"(отправь|отправляй|опубликуй|публикуй|запости|выложи)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func extractTelegramChannel(from text: String) -> String? {
        if let value = firstRegexGroup(in: text, pattern: #"(@[A-Za-z0-9_]{4,})"#) {
            return value
        }
        if let value = firstRegexGroup(in: text, pattern: #"(?:канал|групп[ауеы]?|чат)\s+([A-Za-z0-9_]{4,})"#) {
            return "@\(value)"
        }
        if let value = firstRegexGroup(in: text, pattern: #"(-100\d{6,})"#) {
            return value
        }
        return nil
    }

    private static func telegramParseMode(for text: String) -> String {
        text.range(of: #"</?(b|strong|i|em|u|s|code|pre|a|blockquote)(\s|>|/)"#, options: [.regularExpression, .caseInsensitive]) == nil
            ? "none"
            : "HTML"
    }

    private static func extractTelegramMessage(from text: String) -> String? {
        let patterns = [
            #"(?:напиши|отправь|отправляй|пошли|опубликуй|публикуй|запости)\s+(.+?)\s+(?:в|на)\s+(?:моей\s+|мой\s+|мою\s+)?(?:групп[еу]?|канал|чат|telegram|телеграмм?|тг|@[A-Za-z0-9_]{4,})"#,
            #"(?:в|на)\s+(?:telegram|телеграмм?|тг|групп[еу]?|канал|чат|@[A-Za-z0-9_]{4,}).{0,30}(?:напиши|отправь|отправляй|пошли|опубликуй|публикуй|запости)\s+(.+)$"#
        ]
        for pattern in patterns {
            if let value = firstRegexGroup(in: text, pattern: pattern) {
                let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;\"'«»"))
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    private static func extractRecentAssistantDraft(from history: [ChatMessage], currentText: String) -> String? {
        let lower = currentText.lowercased()
        guard lower.range(of: #"(его|её|ее|это|пост|публикаци|черновик|отправь|отправляй|опубликуй|публикуй|запости|подтверждаю)"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        for message in history.reversed() where message.role == .assistant {
            guard !isOperationalAssistantMessage(message.content) else { continue }
            var lines = message.content.components(separatedBy: .newlines)
            lines.removeAll { line in
                let l = line.lowercased()
                return l.contains("хотите внести изменения")
                    || l.contains("подтвердить публикацию")
                    || l.contains("подтвердите")
                    || l.contains("если хотите отправить")
                    || l.contains("дайте знать")
                    || l.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
                    || l.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            while let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  first.hasPrefix("вот пост") || first.hasPrefix("готовый пост") {
                lines.removeFirst()
            }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        return nil
    }

    private static func isOperationalAssistantMessage(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "укажите группу",
            "в какой telegram",
            "telegram:",
            "не удалось",
            "что отправить",
            "закрепите telegram",
            "telegram подключён"
        ]
        return prefixes.contains { lower.hasPrefix($0) }
    }

    private static func extractRecentTelegramMessage(from history: [ChatMessage]) -> String? {
        for message in history.reversed() where message.role == .user {
            if let text = extractTelegramMessage(from: message.content) {
                return text
            }
        }
        return nil
    }

    private static func firstRegexGroup(in text: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ── memory commands ───────────────────────────────────

    private func handleMemoryCommand(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // "Покажи память" / "Что ты обо мне знаешь?"
        if t.range(of: #"^(покажи\s+память|что\s+ты\s+обо\s+мне\s+знаешь|что\s+знаешь\s+обо\s+мне)"#,
                   options: [.regularExpression, .caseInsensitive]) != nil {
            let ctx = MemoryStore.shared.composeContext()
            return ctx.isEmpty
                ? "Я пока ничего о тебе не знаю. Напиши «Запомни: ...» чтобы сохранить факт."
                : "Вот что я о тебе знаю:\n\n" + ctx
        }

        // "Забудь: X"
        if let what = firstGroup(t, #"^[Зз]абудь[,:]?\s+(.+)$"#) {
            let lower = what.lowercased()
            if let entry = MemoryStore.shared.entries.first(where: {
                $0.key.lowercased() == lower || $0.value.lowercased().contains(lower)
            }) {
                MemoryStore.shared.delete(id: entry.id)
                return "Забыла: \(entry.key) — \(entry.value)"
            }
            return "Не нашла такого воспоминания."
        }

        // "Запомни: X" / "Запомни, что X"
        if let fact = firstGroup(t, #"^[Зз]апомни[,:]?\s+(?:[Чч]то\s+)?(.+)$"#) {
            let key = detectMemoryKey(fact)
            MemoryStore.shared.upsert(key: key, value: fact)
            return "Запомнила: \(key) — \(fact)"
        }

        return nil
    }

    private func handleSocialStyleCommand(_ text: String) -> String? {
        let lower = text.lowercased()
        guard lower.range(
            of: #"(стикерпак|emoji-id|emoji id|custom emoji|кастомн.{0,12}эмодзи|стиль|оформлени).{0,80}(групп|канал|telegram|телеграм|тг|этой группе)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil else { return nil }

        let targets = SocialPublishingTargetStore.shared.selectedTargets()
            .filter { $0.connectorID == "telegram" }
        guard !targets.isEmpty else {
            return "Закрепите Telegram-группу через + → Соц.сети, и я сохраню для неё стиль оформления."
        }

        let stickerPack = Self.firstRegexGroup(
            in: text,
            pattern: #"(?:стикерпак|emoji\s*pack|эмодзи-набор)\s+([@\w\d_\-./:]+)"#
        )
        let customIDsText = Self.firstRegexGroup(
            in: text,
            pattern: #"(?:emoji-id|emoji id|custom emoji|кастомн.{0,12}эмодзи)[:\s]+([A-Za-z0-9_,\-\s]+)"#
        )
        let customIDs = customIDsText?
            .split { $0 == "," || $0 == " " || $0 == "\n" }
            .map(String.init)
            .filter { !$0.isEmpty }
        let style = Self.firstRegexGroup(
            in: text,
            pattern: #"(?:стиль|оформлени[ея]|пиши)\s*(?:такой|так|в стиле)?[:\s]+(.+)$"#
        ) ?? text

        for target in targets {
            SocialPublishingTargetStore.shared.updateStyle(
                targetID: target.id,
                styleGuide: style,
                stickerPackName: stickerPack,
                customEmojiIDs: customIDs
            )
        }
        let names = targets.map(\.destination).joined(separator: ", ")
        return "Запомнила стиль для \(names). Буду учитывать его в следующих Telegram-публикациях."
    }

    private static let memoryKeyRules: [(pattern: String, key: String)] = [
        (#"(меня зовут|моё имя|мое имя|my name|зови меня)"#,               "name"),
        (#"(проект|project|работаю над|создаю|разрабатываю|пишу)"#,         "project"),
        (#"(цель|goal|хочу достичь|планирую запустить|стремлюсь)"#,          "goal"),
        (#"(предпочитаю|предпочтение|нравится когда|prefer|люблю чтобы)"#,   "preference"),
    ]

    private func detectMemoryKey(_ text: String) -> String {
        let lower = text.lowercased()
        for (pattern, key) in Self.memoryKeyRules {
            if lower.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return key
            }
        }
        return "note"
    }

    private func firstGroup(_ text: String, _ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range),
              m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return text[r].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ── Tool scope detection ──────────────────────────────

    static func detectScope(_ text: String) -> ToolScope {
        let lower = text.lowercased()

        // ── -1. Whole-computer control ───────────────────────
        // Use when the user asks Alakeya to operate the visible desktop/app,
        // not just a browser page or a connected service.
        if looksLikeComputerControlRequest(text) {
            print("[ToolScope] detected=computer reason=whole_computer_control text=\"\(text.prefix(80))\"")
            return .computer
        }

        // ── 0. Connector/social actions ───────────────────────
        let connectorPatterns: [String] = [
            #"(telegram|телеграм|телеграмм|тг|vk|вк|вконтакте|instagram|инстаграм|gmail|почт|drive|диск)"#,
            #"(отправь|напиши|пошли|опубликуй|запости|создай\s+черновик|запланируй).{0,80}(сообщен|пост|письм|telegram|телеграм|групп|канал|@[\w_]+)"#,
        ]
        if connectorPatterns.contains(where: {
            lower.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) {
            print("[ToolScope] detected=connectors reason=social_or_connector_action text=\"\(text.prefix(80))\"")
            return .connectors
        }

        // ── 1. Export signals (checked first) ────────────────
        let exportPatterns: [String] = [
            #"(выгруз|экспортир|сохрани).{0,25}(pdf|пдф)"#,
            #"(выгруз|экспортир|сохрани).{0,25}(word|docx|ворд|doc\b)"#,
            #"(выгруз|экспортир|сохрани).{0,25}(csv|excel|эксель|xlsx|таблиц)"#,
            #"(выгруз|экспортир|сохрани).{0,25}(markdown|md\b|файл)"#,
            #"(сделай|создай|генерир).{0,20}(pdf|пдф|word|docx|ворд|csv|excel|xlsx)"#,
            #"\b(export|save as|скачать как)\b.{0,20}(pdf|docx|csv|xlsx|word|markdown)"#,
            #"^(pdf|docx|csv|xlsx|word|ворд|эксель|markdown)$"#,
            #"(скачать|download).{0,20}(pdf|word|csv|excel|xlsx)"#,
            #"\b(в excel|в иксель|в эксель|в csv|в word|в pdf)\b"#,
        ]
        let hasExport = exportPatterns.contains {
            lower.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }

        // ── 2. Local business / maps research signals ─────────
        // Requires: search verb AND (map source OR lead criteria).
        // "Сделай таблицу отелей" has no search verb → .none (correct).
        // "Найди отели с источниками" has no map/lead signal → falls to .research.
        // "Найди салоны в Яндекс Картах" has map source → .localBusinessResearch.
        let searchVerbsPattern = #"(найди|поищи|собери|вытащи|спарси|посмотри|подбери|посоветуй|порекомендуй|рекомендуй|предложи|покажи)\b"#
        let mapSourcesPattern  = #"(яндекс.?карт|yandex.?maps?|яндекс.?бизнес|yandex.?business|2гис|2gis|google.?maps?|гугл.?карт)"#
        let leadCriteriaPattern = #"(без сайта|нет сайта|не было сайта|сайт отсутств|только телефон|без.{0,10}web)"#
        // Contact-focused business search (not generic "найди")
        let contactIntentPattern = #"(найди|собери|вытащи|спарси).{0,35}(контакт|телефон|адрес|email|почт|номер).{0,45}(компани|организаци|салон|клиник|барбершоп|студи|ресторан|кафе|отел|гостиниц|санатор|курорт)"#
        let businessCategoryPattern = #"(салон|парикмахер|барбершоп|клиник|стоматолог|ресторан|кафе|отел|гостиниц|фитнес|массаж|автосервис|юридическ.{0,10}компани)"#

        let hasSearchVerb    = lower.range(of: searchVerbsPattern,    options: [.regularExpression, .caseInsensitive]) != nil
        let hasMapSource     = lower.range(of: mapSourcesPattern,     options: [.regularExpression, .caseInsensitive]) != nil
        let hasLeadFilter    = lower.range(of: leadCriteriaPattern,   options: [.regularExpression, .caseInsensitive]) != nil
        let hasContactIntent = lower.range(of: contactIntentPattern,  options: [.regularExpression, .caseInsensitive]) != nil
        let hasBusinessCategory = lower.range(
            of: businessCategoryPattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let hasHotelOrTravelCategory = lower.range(
            of: #"(отел|гостиниц|санатор|курорт|resort|hotel)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let hasRankingIntent = lower.range(
            of: #"(^|[\s\-])(топ|top)([\s\-\d]|$)|лучш|рейтинг|подборк|самые|сравнени"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let hasRecommendationIntent = lower.range(
            of: #"(подбери|посоветуй|порекомендуй|рекомендуй|предложи|где\s+остановиться|куда\s+поехать|вариант|обзор|отзыв|цены?|стоимост|с\s+бассейн|для\s+семьи|all\s*inclusive|всё\s+включено)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil

        // Rankings/recommendations ("топ отелей Крыма", "лучшие рестораны
        // Ялты", "подбери санаторий") are information research tasks, not
        // map/contact scraping. A phrase like "номера лучших отелей" still
        // needs ranking research first; contact extraction is part of the
        // answer synthesis, not a reason to force map cards.
        if (hasBusinessCategory || hasHotelOrTravelCategory)
            && (hasRankingIntent || (hasHotelOrTravelCategory && hasRecommendationIntent))
            && !hasMapSource && !hasLeadFilter {
            print("[ToolScope] detected=research reason=ranking_or_recommendation_research text=\"\(text.prefix(80))\"")
            return .research
        }

        // Business category is enough to enter the deterministic pipeline.
        // Missing city is handled there with a precise follow-up question.
        let isLocalBusiness = hasSearchVerb
            && (hasMapSource || hasLeadFilter || hasContactIntent || hasBusinessCategory)

        if isLocalBusiness && hasExport {
            print("[ToolScope] detected=localBusinessResearchThenExport reason=searchVerb+mapOrLead+export text=\"\(text.prefix(80))\"")
            return .localBusinessResearchThenExport
        }
        if isLocalBusiness {
            let reason = hasMapSource ? "mapSource"
                : hasLeadFilter ? "leadFilter"
                : hasContactIntent ? "contactIntent"
                : "businessCategory"
            print("[ToolScope] detected=localBusinessResearch reason=searchVerb+\(reason) text=\"\(text.prefix(80))\"")
            return .localBusinessResearch
        }

        // ── 3. Pure export (no research needed) ──────────────
        if hasExport {
            print("[ToolScope] detected=documentExport reason=export_only text=\"\(text.prefix(60))\"")
            return .documentExport
        }

        // ── 4. General web research (headless parser, no visible browser) ──
        // Put this before browser-control detection so "проанализируй сайт/URL",
        // "найди в интернете" and current-information questions do not open
        // the browser pane unless the user explicitly asks to open/navigate it.
        let webResearchPatterns: [String] = [
            #"(найди|поищи|проверь|узнай|посмотри|собери|спарси|вытащи|извлеки|проанализируй).{0,60}(интернет|онлайн|online|web|браузер|сайт|страниц|url|https?://|www\.|\.(com|ru|org|net|io|app|dev)\b)"#,
            #"(https?://|www\.|\.(com|ru|org|net|io|app|dev)\b).{0,60}(проанализируй|извлеки|спарси|вытащи|найди|собери|контакт|цен|текст|таблиц)"#,
            #"(найди|поищи|проверь|узнай|посмотри).{0,50}(последн|новост|актуальн|сегодня|сейчас|цена|цену|курс|рейтинг)"#,
            #"(кто|что|где|когда|сколько|какой|какая|какие).{0,80}(сейчас|сегодня|последн|актуальн|новост|курс|цена|стоимост|рейтинг|202[5-9])"#,
            #"(с источниками|из открытых источников|актуальные данные|из интернета)"#,
            #"(проверь.{0,15}(интернет|онлайн|online|актуальн))"#,
            #"(проанализируй.{0,10}сайт|извлеки.{0,15}с сайта)"#,
        ]
        for pattern in webResearchPatterns {
            if lower.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                print("[ToolScope] detected=research reason=headless_web_research text=\"\(text.prefix(60))\"")
                return .research
            }
        }

        // ── 5. Browser control (navigate, click, scroll, etc.) ──
        let browserControlPatterns: [String] = [
            #"(https?://|www\.|\.(com|ru|org|net|io|app|dev)\b)"#,
            #"(прокрути|scroll|скриншот|screenshot|масштаб|zoom\b)"#,
            #"(очисти.{0,10}(кеш|cache|cookie|куки))"#,
            #"(что.{0,20}открыто|текущ.{0,10}(страниц|сайт))"#,
            #"(опиши.{0,10}(страниц|сайт)|что на (странице|сайте))"#,
            #"(подожди.{0,10}загрузку|дождись загрузки)"#,
            #"\b(browser|браузер)\b"#,
            #"(открой|перейди|зайди).{0,10}(сайт|страниц|ссылк|url|http)"#,
            #"(выдели|подсвети|highlight).{0,20}(элемент|кнопк|блок)"#,
            #"\b(seo|сео|аудит.{0,10}(страниц|сайт))\b"#,
        ]
        for pattern in browserControlPatterns {
            if lower.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                print("[ToolScope] detected=browser reason=browser_control text=\"\(text.prefix(60))\"")
                return .browser
            }
        }

        // ── 7. Plain generation — no tools ───────────────────
        print("[ToolScope] detected=none reason=plain_generation text=\"\(text.prefix(60))\"")
        return .none
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
        case .listDirectory:
            let path = a["path"] ?? "~"
            return Action(type: .listDirectory, title: "Список файлов",
                          description: "Содержимое папки \(path).",
                          target: path, scope: "Файловая система", reversible: true, args: a)
        case .readTextFile:
            let path = a["path"] ?? ""
            return Action(type: .readTextFile, title: "Прочитать файл",
                          description: "Прочитать \(path).",
                          target: path, scope: "Файловая система", reversible: true, args: a)
        case .openFile:
            let path = a["path"] ?? ""
            return Action(type: .openFile, title: "Открыть файл",
                          description: "Открыть \(path) в стандартной программе.",
                          target: path, scope: "Finder", reversible: true, args: a)
        case .createFolder:
            let path = a["path"] ?? ""
            return Action(type: .createFolder, title: "Создать папку",
                          description: "Создать \(path).",
                          target: path, scope: "Файловая система", reversible: true, args: a)
        case .browserOpen:
            let value = a["url"] ?? a["query"] ?? "https://www.google.com"
            return Action(type: .browserOpen, title: "Открыть браузер",
                          description: "Открыть \(value) во встроенном браузере.",
                          target: value, scope: "Браузер Алакеи", reversible: true, args: a)
        case .browserReadPage:
            return Action(type: .browserReadPage, title: "Прочитать страницу",
                          description: "Получить видимый текст и элементы страницы.",
                          target: "Текущая страница", scope: "Только чтение",
                          reversible: true, args: a)
        case .browserBack:
            return Action(type: .browserBack, title: "Вернуться назад",
                          description: "Открыть предыдущую страницу.",
                          target: "История", scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .browserReload:
            return Action(type: .browserReload, title: "Обновить страницу",
                          description: "Перезагрузить текущую страницу.",
                          target: "Текущая страница", scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .browserScroll:
            return Action(type: .browserScroll, title: "Прокрутить страницу",
                          description: "Прокрутить страницу \(a["direction"] ?? "вниз").",
                          target: a["direction"] ?? "down", scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .browserWait:
            return Action(type: .browserWait, title: "Дождаться страницы",
                          description: "Подождать загрузку или обновление.",
                          target: "Текущая страница", scope: "Только чтение",
                          reversible: true, args: a)
        case .browserScreenshot:
            return Action(type: .browserScreenshot, title: "Снимок страницы",
                          description: "Сделать снимок браузера.",
                          target: "Текущая страница", scope: "Только чтение",
                          reversible: true, args: a)
        case .browserClick:
            let text = a["text"] ?? ""
            return Action(type: .browserClick, title: "Нажать на сайте",
                          description: "Нажать элемент «\(text)».",
                          target: text, scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .browserType:
            let field = a["field"] ?? ""
            return Action(type: .browserType, title: "Ввести текст на сайте",
                          description: "Ввести текст в поле «\(field)».",
                          target: field, scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .browserSelect:
            return Action(type: .browserSelect, title: "Выбрать значение",
                          description: "Выбрать «\(a["value"] ?? "")» в списке.",
                          target: a["element_id"] ?? "", scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .browserSubmit:
            return Action(type: .browserSubmit, title: "Отправить форму",
                          description: "Подтвердить действие на сайте.",
                          target: a["element_id"] ?? a["text"] ?? "",
                          scope: "Браузер Алакеи", reversible: false, args: a)
        case .browserHardReload:
            return Action(type: .browserHardReload, title: "Принудительная перезагрузка",
                          description: "Перезагрузить страницу без кеша.",
                          target: "Текущая страница", scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .browserZoom:
            let factor = a["factor"] ?? "1.0"
            return Action(type: .browserZoom, title: "Масштаб браузера",
                          description: "Установить масштаб \(factor).",
                          target: factor, scope: "Браузер Алакеи",
                          reversible: true, args: a)
        case .computerScreenshot:
            return Action(type: .computerScreenshot, title: "Осмотреть экран",
                          description: "Сделать screenshot для управления компьютером.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerWait:
            return Action(type: .computerWait, title: "Подождать",
                          description: "Подождать загрузку интерфейса.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerMouseMove:
            return Action(type: .computerMouseMove, title: "Навести курсор",
                          description: "Переместить курсор.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerClick:
            return Action(type: .computerClick, title: "Кликнуть",
                          description: "Сделать левый клик.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerDoubleClick:
            return Action(type: .computerDoubleClick, title: "Двойной клик",
                          description: "Сделать двойной клик.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerRightClick:
            return Action(type: .computerRightClick, title: "Правый клик",
                          description: "Сделать правый клик.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerDrag:
            return Action(type: .computerDrag, title: "Перетащить",
                          description: "Перетащить мышью.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerScroll:
            return Action(type: .computerScroll, title: "Прокрутить",
                          description: "Прокрутить активную область.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerType:
            return Action(type: .computerType, title: "Ввести текст",
                          description: "Ввести текст в активное поле.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .computerKey:
            return Action(type: .computerKey, title: "Нажать клавиши",
                          description: "Нажать клавишу или сочетание.",
                          target: "Экран", scope: "Computer control",
                          reversible: true, args: a)
        case .browserClearCookies:
            return Action(type: .browserClearCookies, title: "Очистить cookie",
                          description: "Удалить файлы cookie. Вы можете выйти из всех аккаунтов.",
                          target: "Файлы cookie", scope: "Браузер Алакеи",
                          reversible: false, args: a)
        case .browserClearCache:
            return Action(type: .browserClearCache, title: "Очистить кеш",
                          description: "Удалить кеш браузера. Страницы загрузятся медленнее.",
                          target: "Кеш браузера", scope: "Браузер Алакеи",
                          reversible: false, args: a)
        case .browserHighlightElement:
            let t = a["text"] ?? a["element_id"] ?? ""
            return Action(type: .browserHighlightElement, title: "Подсветить элемент",
                          description: "Выделить «\(t)» рамкой на странице.",
                          target: t, scope: "Браузер Алакеи", reversible: true, args: a)
        case .browserExtractData:
            return Action(type: .browserExtractData, title: "Извлечь данные страницы",
                          description: "Получить структурированные данные: контакты, цены, соцсети.",
                          target: "Текущая страница", scope: "Только чтение",
                          reversible: true, args: a)
        case .browserSeoAudit:
            return Action(type: .browserSeoAudit, title: "SEO-аудит страницы",
                          description: "Проверить метатеги, H1, alt, canonical и структуру.",
                          target: "Текущая страница", scope: "Только чтение",
                          reversible: true, args: a)
        case .browserAgentExtract:
            return Action(type: .browserAgentExtract, title: "Быстрый web-парсинг",
                          description: "Извлечь текст, ссылки, контакты и structured data без открытия UI-браузера.",
                          target: a["url"] ?? "", scope: "Read-only parser",
                          reversible: true, args: a)
        case .browserAgentSearch:
            return Action(type: .browserAgentSearch, title: "Быстрый web-поиск и парсинг",
                          description: "Найти страницы и собрать export-ready данные без открытия UI-браузера.",
                          target: a["query"] ?? "", scope: "Read-only parser",
                          reversible: true, args: a)
        case .browserUseAutomate:
            return Action(type: .browserUseAutomate, title: "Browser-use automation",
                          description: "Выполнить многошаговую браузерную задачу через browser-use.",
                          target: a["task"] ?? "", scope: "browser-use",
                          reversible: true, args: a)
        case .browserUseExtract:
            return Action(type: .browserUseExtract, title: "Browser-use extract",
                          description: "Извлечь данные со страницы с JS-rendering.",
                          target: a["url"] ?? "", scope: "browser-use extraction",
                          reversible: true, args: a)
        case .browserUseScreenshot:
            return Action(type: .browserUseScreenshot, title: "Browser-use screenshot",
                          description: "Сделать скриншот страницы с JS-rendering.",
                          target: a["url"] ?? "", scope: "browser-use screenshot",
                          reversible: true, args: a)
        case .browserUseSearch:
            return Action(type: .browserUseSearch, title: "Browser-use search",
                          description: "Выполнить интеллектуальный поиск через browser-use.",
                          target: a["query"] ?? "", scope: "browser-use search",
                          reversible: true, args: a)
        case .browserUseSessionCreate:
            return Action(type: .browserUseSessionCreate, title: "Создать browser-use session",
                          description: "Создать persistent browser-use сессию.",
                          target: "browser-use session", scope: "browser-use session",
                          reversible: true, args: a)
        case .browserUseSessionClose:
            return Action(type: .browserUseSessionClose, title: "Закрыть browser-use session",
                          description: "Закрыть browser-use сессию.",
                          target: a["session_id"] ?? "", scope: "browser-use session",
                          reversible: true, args: a)
        case .connectorRead:
            return Action(type: .connectorRead, title: "Читать данные",
                          description: "Прочитать данные через коннектор.",
                          target: a["tool_name"] ?? "", scope: "Коннекторы",
                          reversible: true, args: a)
        case .connectorWrite:
            return Action(type: .connectorWrite, title: "Записать данные",
                          description: "Записать данные через коннектор. Изменения сохранятся.",
                          target: a["tool_name"] ?? "", scope: "Коннекторы",
                          reversible: false, args: a)
        case .connectorSend:
            return Action(type: .connectorSend, title: "Отправить / опубликовать",
                          description: "Отправить или опубликовать через коннектор. Необратимо.",
                          target: a["tool_name"] ?? "", scope: "Коннекторы",
                          reversible: false, args: a)

        // ── research ──────────────────────────────────────
        case .searchInternet:
            return Action(type: .searchInternet, title: "Поиск в интернете",
                          description: "Найти информацию по запросу без открытия браузера.",
                          target: a["query"] ?? "", scope: "Поиск", reversible: true, args: a)
        case .researchPlan:
            return Action(type: .researchPlan, title: "Составить план исследования",
                          description: "Определить стратегию поиска и необходимые источники.",
                          target: a["query"] ?? "", scope: "Исследование", reversible: true, args: a)
        case .extractSearchResults:
            return Action(type: .extractSearchResults, title: "Извлечь результаты поиска",
                          description: "Спарсить SERP: заголовки, URL, сниппеты.",
                          target: "Поисковая страница", scope: "Только чтение", reversible: true, args: a)
        case .extractBusinessCards:
            return Action(type: .extractBusinessCards, title: "Извлечь карточки компаний",
                          description: "Собрать: название, телефон, адрес, сайт, рейтинг.",
                          target: "Текущая страница", scope: "Только чтение", reversible: true, args: a)
        case .extractHotelCards:
            return Action(type: .extractHotelCards, title: "Извлечь карточки отелей",
                          description: "Собрать: название, звёзды, рейтинг, цена, отзывы.",
                          target: "Текущая страница", scope: "Только чтение", reversible: true, args: a)
        case .extractContactCards:
            return Action(type: .extractContactCards, title: "Извлечь контакты",
                          description: "Собрать телефоны, email, мессенджеры, адреса.",
                          target: "Текущая страница", scope: "Только чтение", reversible: true, args: a)
        case .extractArticle:
            return Action(type: .extractArticle, title: "Прочитать статью",
                          description: "Извлечь чистый текст статьи без рекламы и навигации.",
                          target: "Текущая страница", scope: "Только чтение", reversible: true, args: a)
        case .qualityScoreResults:
            return Action(type: .qualityScoreResults, title: "Оценить качество источников",
                          description: "Ранжировать список источников по авторитетности и актуальности.",
                          target: "Источники", scope: "Только чтение", reversible: true, args: a)

        // ── document export ───────────────────────────────
        case .exportPDF:
            return Action(type: .exportPDF, title: "Создать PDF",
                          description: "Сохранить документ «\(a["title"] ?? "Отчёт")» в ~/Downloads/ как PDF.",
                          target: a["title"] ?? "Отчёт", scope: "Документы", reversible: true, args: a)
        case .exportDocx:
            return Action(type: .exportDocx, title: "Создать Word (DOCX)",
                          description: "Сохранить документ «\(a["title"] ?? "Документ")» как DOCX/RTF.",
                          target: a["title"] ?? "Документ", scope: "Документы", reversible: true, args: a)
        case .exportCSV:
            return Action(type: .exportCSV, title: "Создать CSV",
                          description: "Сохранить таблицу «\(a["title"] ?? "Таблица")» как CSV.",
                          target: a["title"] ?? "Таблица", scope: "Документы", reversible: true, args: a)
        case .exportMarkdown:
            return Action(type: .exportMarkdown, title: "Создать Markdown",
                          description: "Сохранить «\(a["title"] ?? "Файл")» как .md файл.",
                          target: a["title"] ?? "Файл", scope: "Документы", reversible: true, args: a)
        }
    }
}
