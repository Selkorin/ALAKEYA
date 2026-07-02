import Foundation

// ============================================================
// ConnectorExecutor.swift — executor for connector tools.
// ============================================================

final class ConnectorExecutor {
    static let shared = ConnectorExecutor()
    private init() {}

    func execute(toolName: String, args: [String: String]) async throws -> String {
        let connectorID = connectorIDForTool(toolName)

        let (status, connectorTitle) = await MainActor.run {
            let reg = ConnectorRegistry.shared
            let s = reg.states[connectorID]?.status ?? .disconnected
            let t = reg.connectors.first(where: { $0.id == connectorID })?.title ?? connectorID
            return (s, t)
        }

        guard status == .connected else {
            return notConnected(connector: connectorTitle, tool: toolName)
        }

        switch connectorID {
        case "telegram":
            return try await runTelegram(toolName: toolName, args: args)
        case "vk", "instagram":
            return oauthConnectorNotReady(connector: connectorTitle)
        default:
            return "\(connectorTitle): коннектор подключён, но инструмент «\(toolName)» пока не имеет конкретного API-адаптера."
        }
    }

    // MARK: - Connector ID mapping

    private func connectorIDForTool(_ toolName: String) -> String {
        if toolName.hasPrefix("gmail_")         { return "gmail" }
        if toolName.hasPrefix("drive_")         { return "google_drive" }
        if toolName.hasPrefix("docs_")          { return "google_docs" }
        if toolName.hasPrefix("sheets_")        { return "google_sheets" }
        if toolName.hasPrefix("calendar_")      { return "google_calendar" }
        if toolName.hasPrefix("telegram_")      { return "telegram" }
        if toolName.hasPrefix("vk_")            { return "vk" }
        if toolName.hasPrefix("instagram_")     { return "instagram" }
        if toolName.hasPrefix("spreadsheet_")   { return "local_spreadsheet" }
        return "custom_api"
    }

    // MARK: - Telegram

    private func runTelegram(toolName: String, args: [String: String]) async throws -> String {
        switch toolName {
        case "telegram_create_post_draft":
            return try saveTelegramDraft(args: args)
        case "telegram_publish_post":
            return try await publishTelegramPost(args: args)
        case "telegram_schedule_post":
            return "Telegram Bot API не поддерживает нативное отложенное время публикации. Я сохранила черновик; для автопубликации нужен планировщик Alakeya или внешний сервис."
        default:
            return "Telegram: неизвестный инструмент «\(toolName)»."
        }
    }

    private func saveTelegramDraft(args: [String: String]) throws -> String {
        let channel = normalizedTelegramChannel(args["channel"] ?? "")
        let text = args["text"] ?? ""
        guard !channel.isEmpty, !text.isEmpty else {
            throw ConnectorExecError.failed("Telegram: нужны channel и text.")
        }
        let dir = try draftsDirectory()
        let filename = "telegram-\(Int(Date().timeIntervalSince1970)).md"
        let url = dir.appendingPathComponent(filename)
        try """
        # Telegram draft

        Channel: \(channel)

        \(text)
        """.write(to: url, atomically: true, encoding: .utf8)
        return "Telegram: черновик сохранён — \(url.path)"
    }

    private func publishTelegramPost(args: [String: String]) async throws -> String {
        guard let token = ConnectorAuthStore.shared.loadToken(for: "telegram"), !token.isEmpty else {
            throw ConnectorExecError.failed("Telegram Bot Token не найден. Подключите Telegram в настройках.")
        }
        let channel = normalizedTelegramChannel(args["channel"] ?? "")
        var text = args["text"] ?? ""
        let imageDataString = args["images"] ?? ""

        guard !channel.isEmpty else {
            throw ConnectorExecError.failed("Telegram: нужен channel.")
        }

        // Check if we have images to send
        let hasImages = !imageDataString.isEmpty

        if !hasImages {
            // Text-only post validation
            guard !text.isEmpty else {
                throw ConnectorExecError.failed("Telegram: нужен text.")
            }
            guard !looksLikeUnrenderedPostCommand(text) else {
                throw ConnectorExecError.failed("Telegram: я остановила публикацию, потому что вместо готового поста получилась команда пользователя. Сначала нужно сформировать текст поста, затем отправить его.")
            }
        }

        var parseMode = args["parse_mode"] ?? ""
        let prepared = prepareTelegramHTML(text: text, requestedParseMode: parseMode)
        text = prepared.text
        parseMode = prepared.parseMode

        do {
            try await validateTelegramChat(token: token, channel: channel)
        } catch {
            let available = await MainActor.run {
                SocialPublishingTargetStore.shared.connectedTargets()
                    .filter { $0.connectorID == "telegram" }
                    .map { $0.destination }
                    .joined(separator: ", ")
            }
            let suffix = available.isEmpty
                ? "Закрепленных Telegram-групп пока нет."
                : "Доступные закрепленные цели: \(available)."
            throw ConnectorExecError.failed("\(error.localizedDescription)\n\(suffix)")
        }

        // Send with images if present
        if hasImages, let imageData = Data(base64Encoded: imageDataString) {
            return try await sendTelegramPhoto(token: token, channel: channel, text: text, parseMode: parseMode, imageData: imageData)
        }

        // Standard text message
        var request = URLRequest(url: URL(string: "https://api.telegram.org/bot\(token)/sendMessage")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "chat_id": channel,
            "text": text,
            "disable_web_page_preview": false
        ]
        if !parseMode.isEmpty, parseMode.lowercased() != "none" {
            payload["parse_mode"] = parseMode
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(status) else {
            if !parseMode.isEmpty, parseMode.lowercased() != "none" {
                parseMode = "none"
                return try await publishTelegramPost(args: [
                    "channel": channel,
                    "text": stripTelegramHTML(text),
                    "parse_mode": "none"
                ])
            }
            throw ConnectorExecError.failed("Telegram API HTTP \(status): \(body)")
        }
        await MainActor.run {
            SocialPublishingTargetStore.shared.markValidated(connectorID: "telegram", destination: channel)
        }
        return "Telegram: пост опубликован в \(channel)."
    }

    private func sendTelegramPhoto(token: String, channel: String, text: String, parseMode: String, imageData: Data) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.telegram.org/bot\(token)/sendPhoto")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add chat_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(channel)\r\n".data(using: .utf8)!)

        // Add caption (text)
        if !text.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(text)\r\n".data(using: .utf8)!)
        }

        // Add parse_mode if present
        if !parseMode.isEmpty, parseMode.lowercased() != "none" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"parse_mode\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(parseMode)\r\n".data(using: .utf8)!)
        }

        // Add photo
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(status) else {
            throw ConnectorExecError.failed("Telegram API HTTP \(status): \(responseBody)")
        }

        await MainActor.run {
            SocialPublishingTargetStore.shared.markValidated(connectorID: "telegram", destination: channel)
        }
        return "Telegram: фото с текстом опубликовано в \(channel)."
    }

    private func validateTelegramChat(token: String, channel: String) async throws {
        let encoded = channel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? channel
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/getChat?chat_id=\(encoded)") else {
            throw ConnectorExecError.failed("Telegram: некорректный chat_id \(channel).")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(status) else {
            throw ConnectorExecError.failed("Нет доступа к Telegram-группе \(channel). Проверьте, что бот добавлен в эту группу/канал и имеет право писать. Telegram API HTTP \(status): \(body)")
        }
    }

    private func normalizedTelegramChannel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if trimmed.hasPrefix("@") || trimmed.hasPrefix("-") { return trimmed }
        return "@\(trimmed)"
    }

    private func looksLikeUnrenderedPostCommand(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count < 180 else { return false }
        let asksForPost = clean.range(
            of: #"((напиши|создай|сделай|сгенерируй).{0,30}(пост|публикац)|\bпост\s+про|публикаци[яю]\s+про)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let asksToSend = clean.range(
            of: #"(отправь|отправляй|опубликуй|публикуй|запости)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        return asksForPost && asksToSend
    }

    private func prepareTelegramHTML(text: String, requestedParseMode: String) -> (text: String, parseMode: String) {
        var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var parseMode = requestedParseMode
        let hasHTML = output.range(
            of: #"</?(b|strong|i|em|u|s|code|pre|a|blockquote|tg-spoiler|tg-emoji)(\s|>|/)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let hasMarkdown = output.contains("**")
            || output.range(of: #"(?m)^#{1,6}\s+"#, options: .regularExpression) != nil
            || output.range(of: #"(?m)^\s*(Ингредиенты|Приготовление|Хэштеги|CTA|Совет|Факты|Вот факты|Ссылки|Что важно знать):"#, options: [.regularExpression, .caseInsensitive]) != nil

        if hasHTML || hasMarkdown || requestedParseMode.lowercased() == "html" {
            output = convertCommonMarkdownToTelegramHTML(output)
            output = polishTelegramHTML(output)
            parseMode = "HTML"
        }
        return (output, parseMode)
    }

    private func convertCommonMarkdownToTelegramHTML(_ text: String) -> String {
        var output = text
        output = output.replacingOccurrences(
            of: #"(?m)^#{1,6}\s*(.+)$"#,
            with: #"<b>$1</b>"#,
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: #"<b>$1</b>"#,
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)"#,
            with: #"<i>$1</i>"#,
            options: .regularExpression
        )
        return output
    }

    private func polishTelegramHTML(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        lines.removeAll { $0.isEmpty }

        if let index = lines.firstIndex(where: {
            $0.lowercased().range(of: #"^<b>#+\s*хэштеги:?|^#+\s*хэштеги:?|^<b>хэштеги:?<\/b>$|^хэштеги:?$"#, options: .regularExpression) != nil
        }) {
            lines.remove(at: index)
        }

        if let first = lines.first, !first.lowercased().hasPrefix("<b>") {
            lines[0] = "<b>\(first)</b>"
        }

        let sectionLabels = [
            "Ингредиенты", "Приготовление", "Подача", "Совет", "Важно",
            "Что важно знать", "Почему это работает", "Факты", "Вот факты",
            "Ссылки", "Источники", "CTA"
        ]
        for index in lines.indices {
            for label in sectionLabels {
                if lines[index].lowercased().hasPrefix(label.lowercased() + ":"),
                   !lines[index].lowercased().hasPrefix("<b>") {
                    lines[index] = "<b>\(label):</b>" + String(lines[index].dropFirst(label.count + 1))
                }
            }
        }

        return wrapContentBlocks(lines, sectionLabels: sectionLabels).joined(separator: "\n\n")
    }

    private func wrapContentBlocks(_ lines: [String], sectionLabels: [String]) -> [String] {
        var result: [String] = []
        var block: [String] = []
        var quoteAfterSection = false

        func flushBlock() {
            guard !block.isEmpty else { return }
            if quoteAfterSection || block.count >= 2 {
                let tag = block.count >= 4 ? "blockquote expandable" : "blockquote"
                result.append("<\(tag)>\(block.joined(separator: "\n"))</blockquote>")
            } else {
                result.append(contentsOf: block)
            }
            block.removeAll()
            quoteAfterSection = false
        }

        for line in lines {
            let isListLine = line.range(of: #"^(\d+\.|[-—])\s+"#, options: .regularExpression) != nil
            let isSectionLine = sectionLabels.contains { label in
                line.lowercased().hasPrefix("<b>\(label.lowercased()):</b>")
            }
            if isListLine {
                block.append(line)
            } else {
                flushBlock()
                result.append(line)
                quoteAfterSection = isSectionLine && line.range(of: #"</b>\s*$"#, options: .regularExpression) != nil
            }
        }
        flushBlock()
        return result
    }

    private func stripTelegramHTML(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"</?(b|strong|i|em|u|s|code|pre|a|blockquote|tg-spoiler|tg-emoji)(\s+[^>]*)?>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private func draftsDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Alakeya/ConnectorDrafts", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Responses

    private func notConnected(connector: String, tool: String) -> String {
        """
        CONNECTOR_ERROR: коннектор «\(connector)» не подключён.
        Инструмент «\(tool)» недоступен.
        Попроси пользователя открыть Настройки → Коннекторы и подключить «\(connector)».
        Пока можешь помочь вручную: составь нужный текст / документ / список прямо в чате.
        """
    }

    private func oauthConnectorNotReady(connector: String) -> String {
        "\(connector): для публикации нужен завершённый OAuth-вход и access token. Пользователь не должен вводить ключи вручную; настройте OAuth client id в сборке приложения."
    }
}

enum ConnectorExecError: Error, LocalizedError {
    case failed(String)
    var errorDescription: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
