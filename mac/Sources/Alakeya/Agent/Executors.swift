import Foundation
import AppKit
#if canImport(BrowserUse)
import BrowserUse
#endif

// ============================================================
// Executors.swift — the actuator. Semantic-first cascade per DOC1/DOC2:
// Apple Events / AppleScript → Accessibility (AXUIElement) → clipboard
// + ⌘V → CGEvent. Each executor returns a short human summary for the log.
// ============================================================

struct ExecResult {
    let summary: String
    let imageBase64JPEG: String?

    init(summary: String, imageBase64JPEG: String? = nil) {
        self.summary = summary
        self.imageBase64JPEG = imageBase64JPEG
    }
}
enum ExecError: Error, LocalizedError {
    case failed(String)
    var errorDescription: String? { if case let .failed(m) = self { return m }; return nil }
}

private final class PipeCapture {
    private let lock = NSLock()
    private var data = Data()
    private let limit: Int

    init(limit: Int = 3_000_000) {
        self.limit = limit
    }

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        guard data.count < limit else { return }
        let remaining = limit - data.count
        data.append(chunk.prefix(remaining))
    }

    var stringValue: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

final class Executors {
    private let ax = AXController()
    private let script = AppleScriptRunner()
    private let input = InputFallback()
    private let computer = ComputerControl()
    private lazy var screen: ScreenReader? = {
        if #available(macOS 14.0, *) { return ScreenReader() } else { return nil }
    }()

    static func defaultBrowserAgentSearchMode(query: String, requestedMode: String?) -> String {
        if let requestedMode, !requestedMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return requestedMode
        }

        let intent = ResearchIntent.detect(from: query)
        switch intent {
        case .hotelResearch, .travelResearch, .topList, .productResearch, .tableResearch:
            return "search_extract"
        default:
            break
        }

        let lower = query.lowercased()
        let extractionSignals = [
            #"(^|\s)топ([\s-]?\d+)?"#,
            #"лучш"#,
            #"рейтинг"#,
            #"подбери"#,
            #"посоветуй"#,
            #"порекомендуй"#,
            #"сравни"#,
            #"таблиц"#,
            #"подробн"#,
            #"номер"#,
            #"телефон"#,
            #"контакт"#,
        ]
        return extractionSignals.contains {
            lower.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        } ? "search_extract" : "search"
    }

    func run(
        _ action: Action,
        progress: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> ExecResult {
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
        case .browserOpen:
            let value = action.args["url"] ?? action.args["query"] ?? action.target
            await MainActor.run { AlakeyaBrowser.shared.open(value) }
            _ = try? await AlakeyaBrowser.shared.wait(milliseconds: 600)
            let openPage = try await AlakeyaBrowser.shared.readPage()
            return ExecResult(summary: "Открыл: \(value)\nCURRENT_PAGE: \(String(openPage.prefix(8_000)))")
        case .browserReadPage:
            let page = try await AlakeyaBrowser.shared.readPage()
            return ExecResult(summary: page)
        case .browserBack:
            try await AlakeyaBrowser.shared.back()
            _ = try? await AlakeyaBrowser.shared.wait(milliseconds: 400)
            let backPage = try await AlakeyaBrowser.shared.readPage()
            return ExecResult(summary: "Вернулся назад.\nCURRENT_PAGE: \(String(backPage.prefix(8_000)))")
        case .browserReload:
            try await AlakeyaBrowser.shared.reload()
            _ = try? await AlakeyaBrowser.shared.wait(milliseconds: 600)
            let reloadPage = try await AlakeyaBrowser.shared.readPage()
            return ExecResult(summary: "Обновил страницу.\nCURRENT_PAGE: \(String(reloadPage.prefix(8_000)))")
        case .browserScroll:
            let result = try await AlakeyaBrowser.shared.scroll(
                direction: action.args["direction"] ?? "down",
                amount: Int(action.args["amount"] ?? "") ?? 700
            )
            return try await browserVerifiedResult(result)
        case .browserWait:
            let result = try await AlakeyaBrowser.shared.wait(
                milliseconds: Int(action.args["milliseconds"] ?? "") ?? 800
            )
            return try await browserVerifiedResult(result)
        case .browserScreenshot:
            _ = try await AlakeyaBrowser.shared.store.takeScreenshotAndCopy()
            return ExecResult(summary: "Скриншот скопирован в буфер обмена. Вставь в чат через ⌘V.")
        case .browserHighlightElement:
            let result = try await AlakeyaBrowser.shared.highlightElement(
                elementID: action.args["element_id"] ?? "",
                textSearch: action.args["text"] ?? action.target,
                color: action.args["color"] ?? "",
                durationMs: Int(action.args["duration_ms"] ?? "") ?? 4000,
                label: action.args["label"] ?? ""
            )
            return ExecResult(summary: "Элемент подсвечен.\nRESULT: \(result)")
        case .browserExtractData:
            let data = try await AlakeyaBrowser.shared.extractPageData()
            return ExecResult(summary: "EXTRACTED_DATA: \(data)")
        case .browserSeoAudit:
            let data = try await AlakeyaBrowser.shared.seoAudit()
            return ExecResult(summary: "SEO_AUDIT: \(data)")
        case .browserAgentExtract:
            let data = try await runBrowserAgentTool(action, progress: progress)
            return ExecResult(summary: "BROWSER_AGENT_EXTRACT:\n\(data)")
        case .browserAgentSearch:
            let data = try await runBrowserAgentTool(action, progress: progress)
            return ExecResult(summary: "BROWSER_AGENT_SEARCH:\n\(data)")
        case .browserUseAutomate:
            let data = try await runBrowserUseTool(action)
            return ExecResult(summary: "BROWSER_USE_AUTOMATE:\n\(data)")
        case .browserUseExtract:
            let data = try await runBrowserUseTool(action)
            return ExecResult(summary: "BROWSER_USE_EXTRACT:\n\(data)")
        case .browserUseScreenshot:
            let data = try await runBrowserUseTool(action)
            return ExecResult(summary: "BROWSER_USE_SCREENSHOT:\n\(data)")
        case .browserUseSearch:
            let data = try await runBrowserUseTool(action)
            return ExecResult(summary: "BROWSER_USE_SEARCH:\n\(data)")
        case .browserUseSessionCreate:
            let sessionID = try await runBrowserUseSessionCreate(action)
            return ExecResult(summary: "SESSION_CREATED: \(sessionID)")
        case .browserUseSessionClose:
            let result = try await runBrowserUseSessionClose(action)
            return ExecResult(summary: "SESSION_CLOSED: \(result)")
        case .browserHardReload:
            try await AlakeyaBrowser.shared.hardReload()
            _ = try? await AlakeyaBrowser.shared.wait(milliseconds: 600)
            let hardPage = try await AlakeyaBrowser.shared.readPage()
            return ExecResult(summary: "Принудительно перезагрузил страницу.\nCURRENT_PAGE: \(String(hardPage.prefix(8_000)))")
        case .browserZoom:
            let factor = Double(action.args["factor"] ?? "1.0") ?? 1.0
            try await AlakeyaBrowser.shared.setZoom(CGFloat(factor))
            return ExecResult(summary: "Масштаб установлен: \(Int(factor * 100))%.")
        case .computerScreenshot:
            let shot = try await computer.screenshotForAI()
            return ExecResult(summary: """
            COMPUTER_SCREENSHOT:
            source_size: \(Int(shot.sourceSize.width))x\(Int(shot.sourceSize.height))
            ai_size: \(Int(shot.aiSize.width))x\(Int(shot.aiSize.height))
            coordinate_space: 1280x800
            image: attached JPEG
            """, imageBase64JPEG: shot.base64JPEG)
        case .computerWait:
            let seconds = min(max(Double(action.args["seconds"] ?? "") ?? 1.0, 0.2), 5.0)
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return ExecResult(summary: "Подождал \(String(format: "%.1f", seconds)) сек.")
        case .browserClearCookies:
            try await AlakeyaBrowser.shared.clearCookies()
            return ExecResult(summary: "Файлы cookie очищены.")
        case .browserClearCache:
            try await AlakeyaBrowser.shared.clearCache()
            return ExecResult(summary: "Кеш браузера очищен.")

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

        // ── file operations ───────────────────────────────
        case .listDirectory:
            let resolved = Self.resolvePath(action.args["path"] ?? "~")
            let items = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: resolved),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            let lines = items
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map { item -> String in
                    let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return isDir ? "\(item.lastPathComponent)/" : item.lastPathComponent
                }
            let listing = lines.isEmpty ? "(пусто)" : lines.joined(separator: "\n")
            return ExecResult(summary: "Содержимое \(resolved):\n\(listing)")

        case .readTextFile:
            let resolved = Self.resolvePath(action.args["path"] ?? "")
            guard !Self.isDangerousPath(resolved) else {
                throw ExecError.failed("Путь запрещён из соображений безопасности.")
            }
            guard let text = try? String(contentsOf: URL(fileURLWithPath: resolved), encoding: .utf8) else {
                throw ExecError.failed("Файл не найден или не является текстовым: \(resolved)")
            }
            let truncated = text.count > 8_000
                ? String(text.prefix(8_000)) + "\n...[усечено]"
                : text
            return ExecResult(summary: truncated)

        case .openFile:
            let resolved = Self.resolvePath(action.args["path"] ?? "")
            let ok = NSWorkspace.shared.open(URL(fileURLWithPath: resolved))
            guard ok else { throw ExecError.failed("Не удалось открыть: \(resolved)") }
            return ExecResult(summary: "Открыл: \(resolved)")

        case .createFolder:
            let resolved = URL(fileURLWithPath: Self.resolvePath(action.args["path"] ?? "")).standardized
            let desktop   = URL(fileURLWithPath: "\(NSHomeDirectory())/Desktop").standardized
            guard resolved != desktop else {
                throw ExecError.failed("Не указано имя новой папки. Например: ~/Desktop/AlakeyaTest")
            }
            if FileManager.default.fileExists(atPath: resolved.path) {
                return ExecResult(summary: "Папка уже существует: \(resolved.path)")
            }
            try FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)
            let existsAfter = FileManager.default.fileExists(atPath: resolved.path)
            guard existsAfter else {
                throw ExecError.failed("Папка не была создана: \(resolved.path)")
            }
            return ExecResult(summary: "Создал папку: \(resolved.path)")
        case .browserClick:
            let result = try await AlakeyaBrowser.shared.click(
                elementID: action.args["element_id"] ?? "",
                text: action.args["text"] ?? action.target
            )
            return try await browserVerifiedResult(result)
        case .browserType:
            let result = try await AlakeyaBrowser.shared.type(
                text: action.args["text"] ?? "",
                elementID: action.args["element_id"] ?? "",
                field: action.args["field"] ?? action.target
            )
            return try await browserVerifiedResult(result)
        case .browserSelect:
            let result = try await AlakeyaBrowser.shared.select(
                elementID: action.args["element_id"] ?? action.target,
                value: action.args["value"] ?? ""
            )
            return try await browserVerifiedResult(result)
        case .computerMouseMove:
            let point = try computerPoint(from: action.args)
            computer.moveMouse(x: point.x, y: point.y)
            return ExecResult(summary: "Навёл курсор на \(Int(point.x)), \(Int(point.y)).")
        case .computerClick:
            let point = try computerPoint(from: action.args)
            computer.click(x: point.x, y: point.y)
            return ExecResult(summary: "Кликнул по \(Int(point.x)), \(Int(point.y)).")
        case .computerDoubleClick:
            let point = try computerPoint(from: action.args)
            computer.click(x: point.x, y: point.y, clickCount: 2)
            return ExecResult(summary: "Двойной клик по \(Int(point.x)), \(Int(point.y)).")
        case .computerRightClick:
            let point = try computerPoint(from: action.args)
            computer.click(x: point.x, y: point.y, button: .right)
            return ExecResult(summary: "Правый клик по \(Int(point.x)), \(Int(point.y)).")
        case .computerDrag:
            let startX = try Self.requiredDouble(action.args["start_x"], label: "start_x")
            let startY = try Self.requiredDouble(action.args["start_y"], label: "start_y")
            let end = try computerPoint(from: action.args)
            computer.drag(fromX: startX, fromY: startY, toX: end.x, toY: end.y)
            return ExecResult(summary: "Перетащил от \(Int(startX)), \(Int(startY)) до \(Int(end.x)), \(Int(end.y)).")
        case .computerScroll:
            let direction = action.args["direction"] ?? "down"
            let amount = min(max(Int(action.args["amount"] ?? "") ?? 3, 1), 10)
            computer.scroll(direction: direction, amount: amount)
            return ExecResult(summary: "Прокрутил \(direction) на \(amount).")
        case .computerType:
            let text = action.args["text"] ?? ""
            computer.typeText(text)
            return ExecResult(summary: "Ввёл текст через computer control (\(text.count) симв.).")
        case .computerKey:
            let key = action.args["key"] ?? ""
            try computer.pressKey(key)
            return ExecResult(summary: "Нажал \(key).")

        // ── connectors ────────────────────────────────────
        case .connectorRead, .connectorWrite, .connectorSend:
            let result = try await ConnectorExecutor.shared.execute(
                toolName: action.args["tool_name"] ?? action.type.rawValue,
                args: action.args
            )
            return ExecResult(summary: result)

        // ── research tools ────────────────────────────────
        case .searchInternet:
            let query = action.args["query"] ?? ""
            let maxResults = Int(action.args["max_results"] ?? "") ?? 15
            let mode = Self.defaultBrowserAgentSearchMode(query: query, requestedMode: action.args["mode"])
            let shouldExtract = mode == "search_extract"
            var args = action.args
            args["query"] = query
            args["mode"] = mode
            args["goal"] = args["goal"] ?? (shouldExtract ? "ranked_final_answer" : "search")
            args["max_results"] = "\(shouldExtract ? Swift.max(5, Swift.min(maxResults, 6)) : maxResults)"
            args["max_links"] = args["max_links"] ?? (shouldExtract ? "30" : "80")
            args["max_text_chars"] = args["max_text_chars"] ?? (shouldExtract ? "3500" : "1000")
            args["timeout"] = args["timeout"] ?? (shouldExtract ? "6" : "5")
            let results = try await runBrowserAgentTool(Action(
                type: .browserAgentSearch,
                title: "Headless web-поиск",
                description: "Ищу в интернете через быстрый parser без UI-браузера.",
                target: query,
                scope: "Read-only web parser",
                args: args
            ), progress: progress)
            return ExecResult(summary: "SEARCH_INTERNET_RESULTS:\n" + results)

        case .researchPlan:
            let query  = action.args["query"] ?? ""
            let plan   = SearchQueryPlanner.plan(for: query)
            let intent = ResearchIntent.detect(from: query)
            let planJSON = (try? String(data: JSONEncoder().encode(plan), encoding: .utf8)) ?? "{}"
            return ExecResult(summary: """
            RESEARCH_PLAN:
            Intent: \(intent.rawValue)
            Playbook: \(intent.playbook)
            Min sources: \(intent.minSources), Min results: \(intent.minResults)
            Queries: \(plan.queries.enumerated().map { "\($0.offset+1). \($0.element)" }.joined(separator: "\n"))
            Extraction goal: \(plan.extractionGoal)
            Fields: \(plan.dataFields.joined(separator: ", "))
            \(planJSON)
            """)

        case .extractSearchResults:
            let html = try await AlakeyaBrowser.shared.extractSearchResults()
            return ExecResult(summary: "SEARCH_RESULTS:\n\(html)")

        case .extractBusinessCards:
            let maxCards = Int(action.args["max_cards"] ?? "") ?? 20
            let cards = try await AlakeyaBrowser.shared.extractBusinessCards(maxCards: maxCards)
            return ExecResult(summary: "BUSINESS_CARDS:\n\(cards)")

        case .extractHotelCards:
            let maxCards = Int(action.args["max_cards"] ?? "") ?? 20
            let cards = try await AlakeyaBrowser.shared.extractHotelCards(maxCards: maxCards)
            return ExecResult(summary: "HOTEL_CARDS:\n\(cards)")

        case .extractContactCards:
            let contacts = try await AlakeyaBrowser.shared.extractContactCards()
            return ExecResult(summary: "CONTACT_CARDS:\n\(contacts)")

        case .extractArticle:
            let maxChars = Int(action.args["max_chars"] ?? "") ?? 6000
            let article = try await AlakeyaBrowser.shared.extractArticle(maxChars: maxChars)
            return ExecResult(summary: "ARTICLE:\n\(article)")

        case .qualityScoreResults:
            let sourcesJSON = action.args["sources_json"] ?? "[]"
            // Decode JSON array of {url, title, snippet} objects into typed tuples for rankJSON.
            struct SrcEntry: Decodable { var url, title: String; var snippet: String? }
            let entries = (try? JSONDecoder().decode([SrcEntry].self,
                           from: sourcesJSON.data(using: .utf8) ?? Data())) ?? []
            let tuples  = entries.map { (url: $0.url, title: $0.title, snippet: $0.snippet ?? "") }
            let scored  = SourceQualityScorer.rankJSON(tuples)
            return ExecResult(summary: "SCORED_RESULTS:\n\(scored)")

        // ── document export ───────────────────────────────
        case .exportPDF:
            let title   = action.args["title"] ?? "Отчёт"
            let content = action.args["content"] ?? ""
            if let denied = ExportGuard.checkText(content, label: "PDF") {
                return ExecResult(summary: denied)
            }
            let doc = buildReportDoc(title: title, content: content)
            let file = try await DocumentExportManager.shared.export(doc, as: .pdf)
            let attachment = ExportedFileAttachment(from: file, sourceTool: "export_pdf")
            await MainActor.run { ExportResultStore.shared.add(attachment) }
            print("[Export] format=pdf path=\(file.path.lastPathComponent)")
            return ExecResult(summary: "Готово — PDF создан.")

        case .exportDocx:
            let title   = action.args["title"] ?? "Документ"
            let content = action.args["content"] ?? ""
            if let denied = ExportGuard.checkText(content, label: "DOCX") {
                return ExecResult(summary: denied)
            }
            let doc = buildReportDoc(title: title, content: content)
            let file = try await DocumentExportManager.shared.export(doc, as: .docx)
            let attachment = ExportedFileAttachment(from: file, sourceTool: "export_docx")
            await MainActor.run { ExportResultStore.shared.add(attachment) }
            let isRTF = file.format == .rtf
            print("[Export] format=\(isRTF ? "rtf" : "docx") path=\(file.path.lastPathComponent)")
            return ExecResult(summary: isRTF
                ? "Готово — создан RTF-документ, его можно открыть в Word или Pages."
                : "Готово — DOCX создан.")

        case .exportCSV:
            let title       = action.args["title"] ?? "Таблица"
            let content     = action.args["content"] ?? ""
            let headersJSON = action.args["headers_json"] ?? "[]"
            let rowsJSON    = action.args["rows_json"]    ?? "[]"
            var headers = (try? JSONDecoder().decode([String].self,
                           from: headersJSON.data(using: .utf8) ?? Data())) ?? []
            var rows    = (try? JSONDecoder().decode([[String]].self,
                           from: rowsJSON.data(using: .utf8) ?? Data())) ?? []
            if headers.isEmpty, !content.isEmpty {
                if let parsed = MarkdownTableParser.parse(from: content).first {
                    headers = parsed.headers
                    rows    = parsed.rows
                }
            }
            if let denied = ExportGuard.checkTable(headers: headers, rows: rows, label: "CSV") {
                return ExecResult(summary: denied)
            }
            let file: ExportedFile
            if !headers.isEmpty {
                file = try await DocumentExportManager.shared.exportTable(
                    title: title, headers: headers, rows: rows, as: .csv)
            } else {
                file = try await DocumentExportManager.shared.exportText(content, title: title, as: .csv)
            }
            let attachment = ExportedFileAttachment(from: file, sourceTool: "export_csv")
            await MainActor.run { ExportResultStore.shared.add(attachment) }
            print("[Export] format=csv rows=\(rows.count) path=\(file.path.lastPathComponent)")
            return ExecResult(summary: "Готово — CSV создан для Excel/Numbers.")

        case .exportMarkdown:
            let title   = action.args["title"] ?? "Файл"
            let content = action.args["content"] ?? ""
            if let denied = ExportGuard.checkText(content, label: "Markdown") {
                return ExecResult(summary: denied)
            }
            let file = try await DocumentExportManager.shared.exportText(content, title: title, as: .markdown)
            let attachment = ExportedFileAttachment(from: file, sourceTool: "export_markdown")
            await MainActor.run { ExportResultStore.shared.add(attachment) }
            print("[Export] format=markdown path=\(file.path.lastPathComponent)")
            return ExecResult(summary: "Готово — Markdown-файл создан.")

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
        case .browserSubmit:
            let result = try await AlakeyaBrowser.shared.submit(
                elementID: action.args["element_id"] ?? "",
                text: action.args["text"] ?? action.target
            )
            _ = try await AlakeyaBrowser.shared.wait(milliseconds: 500)
            return try await browserVerifiedResult(result)
        }
    }

    // ── report document builder ───────────────────────────

    private func computerPoint(from args: [String: String]) throws -> (x: Double, y: Double) {
        let x = try Self.requiredDouble(args["x"], label: "x")
        let y = try Self.requiredDouble(args["y"], label: "y")
        guard (0...1280).contains(x), (0...800).contains(y) else {
            throw ExecError.failed("Координаты computer tool должны быть в диапазоне 0...1280 по X и 0...800 по Y.")
        }
        return (x, y)
    }

    private static func requiredDouble(_ raw: String?, label: String) throws -> Double {
        guard let raw, let value = Double(raw) else {
            throw ExecError.failed("Не указан числовой параметр \(label).")
        }
        return value
    }

    private func buildReportDoc(title: String, content: String) -> ReportDocument {
        // Parse markdown tables from content, build sections
        let tables = MarkdownTableParser.parse(from: content)
        let cleanedBody = tables.isEmpty
            ? ReportContentNormalizer.normalize(content)
            : ReportContentNormalizer.normalize(MarkdownTableParser.removeTables(from: content))

        var sections: [ReportSection] = []
        if !cleanedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append(ReportSection(heading: "", body: cleanedBody))
        }
        for t in tables {
            sections.append(ReportSection(heading: "", table: ReportTable(headers: t.headers, rows: t.rows)))
        }
        if sections.isEmpty {
            sections.append(ReportSection(heading: "", body: content))
        }
        return ReportDocument(title: title, sections: sections)
    }

    private func runBrowserAgentTool(
        _ action: Action,
        progress: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let url = action.args["url"] ?? (action.type == .browserAgentExtract ? action.target : "")
        let query = action.args["query"] ?? (action.type == .browserAgentSearch ? action.target : "")
        let toolName = action.type.rawValue
        if action.type == .browserAgentExtract,
           url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ExecError.failed("Не указан URL для \(toolName).")
        }
        if action.type == .browserAgentSearch,
           query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ExecError.failed("Не указан query для \(toolName).")
        }

        let devScriptPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/browser_agent_extract.py").path
        let bundledScriptPath = Bundle.main.resourceURL?
            .appendingPathComponent("scripts/browser_agent_extract.py").path
        let scriptPath = [devScriptPath, bundledScriptPath]
            .compactMap { $0 }
            .first { FileManager.default.fileExists(atPath: $0) }

        guard let scriptPath else {
            throw ExecError.failed("Runner browser_agent_extract.py не найден.")
        }

        let defaultMode = action.type == .browserAgentSearch ? "search_extract" : "extract"
        let defaultMaxText = action.type == .browserAgentSearch ? "3000" : "12000"
        let processTimeout = Double(action.args["process_timeout"] ?? "")
            ?? (action.type == .browserAgentSearch ? 32.0 : 24.0)
        if action.type == .browserAgentSearch {
            await progress?("Ищу спокойно через DuckDuckGo/Bing/Mojeek: \(query)")
        } else {
            await progress?("Открываю источник: \(url)")
        }
        var arguments = [
            scriptPath,
            "--mode", action.args["mode"] ?? defaultMode,
            "--goal", action.args["goal"] ?? "extract",
            "--max-links", action.args["max_links"] ?? "80",
            "--max-text-chars", action.args["max_text_chars"] ?? defaultMaxText,
            "--max-results", action.args["max_results"] ?? "3",
            "--timeout", action.args["timeout"] ?? "10",
        ]
        if !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--url", url])
        }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--query", query])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["ALAKEYA_POLITE_FETCH_DELAY"] = environment["ALAKEYA_POLITE_FETCH_DELAY"] ?? "1.8"
        environment["ALAKEYA_ALLOW_GOOGLE_SEARCH"] = environment["ALAKEYA_ALLOW_GOOGLE_SEARCH"] ?? "0"
        process.environment = environment

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        let stdoutCapture = PipeCapture()
        let stderrCapture = PipeCapture()
        out.fileHandleForReading.readabilityHandler = { handle in
            stdoutCapture.append(handle.availableData)
        }
        err.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            stderrCapture.append(chunk)
            guard let progress,
                  let text = String(data: chunk, encoding: .utf8) else { return }
            for rawLine in text.split(whereSeparator: \.isNewline) {
                let line = String(rawLine)
                guard line.hasPrefix("PROGRESS:") else { continue }
                let message = String(line.dropFirst("PROGRESS:".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !message.isEmpty else { continue }
                Task { @MainActor in progress(message) }
            }
        }
        try process.run()
        let startedAt = Date()
        while process.isRunning && Date().timeIntervalSince(startedAt) < processTimeout {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if process.isRunning {
            process.terminate()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if process.isRunning {
                let killer = Process()
                killer.executableURL = URL(fileURLWithPath: "/bin/kill")
                killer.arguments = ["-9", "\(process.processIdentifier)"]
                try? killer.run()
                killer.waitUntilExit()
            }
            throw ExecError.failed("\(toolName) timed out after \(Int(processTimeout))s")
        }

        out.fileHandleForReading.readabilityHandler = nil
        err.fileHandleForReading.readabilityHandler = nil
        stdoutCapture.append(out.fileHandleForReading.readDataToEndOfFile())
        stderrCapture.append(err.fileHandleForReading.readDataToEndOfFile())
        let stdout = stdoutCapture.stringValue
        let stderr = Self.stripProgressLines(stderrCapture.stringValue)

        guard process.terminationStatus == 0 else {
            throw ExecError.failed("\(toolName) failed: \(stderr.isEmpty ? stdout : stderr)")
        }

        let formatted = Self.formatBrowserAgentOutput(stdout)
        return formatted.count > 24_000 ? String(formatted.prefix(24_000)) + "\n...[усечено]" : formatted
    }

    private static func formatBrowserAgentOutput(_ stdout: String) -> String {
        guard
            let data = stdout.data(using: .utf8),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let headers = payload["headers"] as? [String],
            let rows = payload["rows"] as? [[String]],
            !headers.isEmpty,
            !rows.isEmpty
        else {
            return stdout
        }

        let table = ParsedMarkdownTable(headers: headers, rows: rows, caption: nil).toMarkdown()
        return """
        EXPORT_TABLE:
        \(table)

        RAW_JSON:
        \(stdout)
        """
    }

    private static func stripProgressLines(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .filter { !$0.hasPrefix("PROGRESS:") }
            .joined(separator: "\n")
    }

    private func runBrowserUseTool(_ action: Action) async throws -> String {
        // Check if service is available
        let serviceAvailable = await BrowserUseClient.shared.isServiceAvailable()
        guard serviceAvailable else {
            switch action.type {
            case .browserUseSearch:
                var args = action.args
                args["query"] = args["query"] ?? action.target
                args["mode"] = args["mode"] ?? "search_extract"
                args["goal"] = args["extraction_goal"] ?? args["goal"] ?? "extract"
                return try await runBrowserAgentTool(Action(
                    type: .browserAgentSearch,
                    title: "Fallback fast web-поиск",
                    description: "browser-use service недоступен, использую быстрый parser.",
                    target: args["query"] ?? action.target,
                    scope: "Read-only parser fallback",
                    args: args
                ))
            case .browserUseExtract:
                var args = action.args
                args["url"] = args["url"] ?? action.target
                args["goal"] = args["goal"] ?? "extract"
                return try await runBrowserAgentTool(Action(
                    type: .browserAgentExtract,
                    title: "Fallback fast web-парсинг",
                    description: "browser-use service недоступен, использую быстрый parser.",
                    target: args["url"] ?? action.target,
                    scope: "Read-only parser fallback",
                    args: args
                ))
            default:
                break
            }
            throw ExecError.failed("""
            ⚠️ browser-use service недоступен.

            Запустите сервис:
            cd /Users/werni/Selkorin/mac/browser_use_service
            bash start_server.sh

            Fallback: Используйте browser_agent_extract
            """)
        }

        do {
            switch action.type {
            case .browserUseAutomate:
                let task = action.args["task"] ?? action.target
                let sessionID = action.args["session_id"]
                let maxSteps = action.args["max_steps"].flatMap { Int($0) }
                let screenshotEveryStep = action.args["screenshot_every_step"]?.lowercased() == "true"
                let waitForTimeout = action.args["wait_for_timeout"].flatMap { Int($0) }

                let options = AutomateOptions(
                    maxSteps: maxSteps,
                    screenshotEveryStep: screenshotEveryStep,
                    waitForTimeout: waitForTimeout
                )

                let result = try await BrowserUseClient.shared.automate(
                    task: task,
                    sessionID: sessionID,
                    options: options
                )

                return formatJSONResult(result)

            case .browserUseExtract:
                let url = action.args["url"] ?? action.target
                let goal = action.args["goal"] ?? "extract"
                let sessionID = action.args["session_id"]
                let includeScreenshots = action.args["include_screenshots"]?.lowercased() == "true"
                let waitForDynamicContent = action.args["wait_for_dynamic_content"]?.lowercased() != "false"

                let options = ExtractOptions(
                    includeScreenshots: includeScreenshots,
                    waitForDynamicContent: waitForDynamicContent
                )

                let result = try await BrowserUseClient.shared.extract(
                    url: url,
                    goal: goal,
                    sessionID: sessionID,
                    options: options
                )

                return formatJSONResult(result)

            case .browserUseScreenshot:
                let url = action.args["url"] ?? action.target
                let sessionID = action.args["session_id"]
                let fullPage = action.args["full_page"]?.lowercased() == "true"
                let waitForRender = action.args["wait_for_render"].flatMap { Int($0) }

                let options = ScreenshotOptions(
                    fullPage: fullPage,
                    waitForRender: waitForRender
                )

                let result = try await BrowserUseClient.shared.captureScreenshot(
                    url: url,
                    sessionID: sessionID,
                    options: options
                )

                return formatJSONResult(result)

            case .browserUseSearch:
                let query = action.args["query"] ?? action.target
                let maxResults = action.args["max_results"].flatMap { Int($0) } ?? 5
                let extractionGoal = action.args["extraction_goal"] ?? "summary"
                let includeScreenshots = action.args["include_screenshots"]?.lowercased() == "true"

                let options = SearchOptions(includeScreenshots: includeScreenshots)

                let result = try await BrowserUseClient.shared.search(
                    query: query,
                    maxResults: maxResults,
                    extractionGoal: extractionGoal,
                    options: options
                )

                return formatBrowserUseSearchResult(result)

            default:
                throw ExecError.failed("Unsupported browser-use action: \(action.type.rawValue)")
            }
        } catch let error {
            // Check if error is about missing API key
            let errorText = error.localizedDescription
            if errorText.contains("API_KEY") || errorText.contains("api key") {
                throw ExecError.failed("""
                ⚠️ browser-use требует API ключ для поиска.

                Получите бесплатный API ключ: https://cloud.browser-use.com/new-api-key

                Затем добавьте в browser_use_service/.env:
                OPENAI_API_KEY=sk-... (или ANTHROPIC_API_KEY)

                Для простого извлечения используйте browser_use_extract без поиска.
                """)
            } else {
                throw error
            }
        }
    }

    private func runBrowserUseSessionCreate(_ action: Action) async throws -> String {
        let serviceAvailable = await BrowserUseClient.shared.isServiceAvailable()
        guard serviceAvailable else {
            throw ExecError.failed("browser-use service недоступен. Запустите сервис через browser_use_service/start_server.sh")
        }

        let headless = action.args["headless"]?.lowercased() != "false"
        let userAgent = action.args["user_agent"]
        let viewportWidth = action.args["viewport_width"].flatMap { Int($0) }
        let viewportHeight = action.args["viewport_height"].flatMap { Int($0) }

        var options: [String: Any] = [:]
        options["headless"] = headless
        if let userAgent = userAgent {
            options["user_agent"] = userAgent
        }
        if let width = viewportWidth, let height = viewportHeight {
            options["viewport"] = ["width": width, "height": height]
        }

        let sessionID = try await BrowserUseClient.shared.createSession(options: options)

        return "Session created: \(sessionID)"
    }

    private func runBrowserUseSessionClose(_ action: Action) async throws -> String {
        let serviceAvailable = await BrowserUseClient.shared.isServiceAvailable()
        guard serviceAvailable else {
            throw ExecError.failed("browser-use service недоступен")
        }

        let sessionID = action.args["session_id"] ?? ""

        if sessionID.isEmpty {
            return "No session ID provided, skipping close"
        }

        try await BrowserUseClient.shared.closeSession(sessionID)

        return "Session closed: \(sessionID)"
    }

    private func formatJSONResult(_ result: [String: Any]) -> String {
        // Convert dictionary to formatted JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        } else {
            return String(describing: result)
        }
    }

    private func formatBrowserUseSearchResult(_ result: [String: Any]) -> String {
        let json = formatJSONResult(result)
        guard let results = result["results"] as? [[String: Any]], !results.isEmpty else {
            return json
        }

        let headers = ["rank", "title", "url", "snippet", "method"]
        let method = "\(result["method"] ?? "browser_use")"
        let rows = results.map { item in
            [
                "\(item["rank"] ?? "")",
                "\(item["title"] ?? "")",
                "\(item["url"] ?? "")",
                "\(item["snippet"] ?? "")",
                method,
            ]
        }
        let table = ParsedMarkdownTable(headers: headers, rows: rows, caption: nil).toMarkdown()
        return """
        EXPORT_TABLE:
        \(table)

        RAW_JSON:
        \(json)
        """
    }

    private func formatBrowserUseError(_ error: Error) -> String {
        let errorText = error.localizedDescription

        // Check if error is about missing API key
        if errorText.contains("API_KEY") || errorText.contains("api key") {
            return """
            ⚠️ browser-use требует API ключ для поиска.

            Получите бесплатный API ключ: https://cloud.browser-use.com/new-api-key

            Затем добавьте в browser_use_service/.env:
            OPENAI_API_KEY=sk-... (или ANTHROPIC_API_KEY)

            Или используйте browser_use_extract для простых задач.
            """
        }

        // Check if service unavailable
        if errorText.contains("недоступен") || errorText.contains("unavailable") {
            return """
            ⚠️ browser-use сервис недоступен.

            Запустите сервис:
            cd /Users/werni/Selkorin/mac/browser_use_service
            bash start_server.sh

            Fallback: Используйте browser_agent_extract
            """
        }

        return "❌ Ошибка browser-use: \(errorText)"
    }

    // ── path safety and normalization ─────────────────────
    private static func isDangerousPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        let blocked = ["/.ssh", "/library/keychains", "/.gnupg", ".env", ".pem", ".key", ".p12", ".pfx"]
        return blocked.contains { lower.contains($0) }
    }

    // Resolves Russian/English Desktop aliases and bare names to absolute paths.
    // "рабочий стол" / "Desktop" → ~/Desktop
    // "AlakeyaTest" (no slash)   → ~/Desktop/AlakeyaTest (creates on Desktop by default)
    // "relative/sub"             → ~/relative/sub
    private static func resolvePath(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty            { return "\(NSHomeDirectory())/Desktop" }
        if s.hasPrefix("/")     { return s }
        if s.hasPrefix("~")     { return (s as NSString).expandingTildeInPath }
        let lower = s.lowercased()
        let home = NSHomeDirectory()
        if lower == "desktop" || lower == "рабочий стол" { return "\(home)/Desktop" }
        if !s.contains("/")     { return "\(home)/Desktop/\(s)" }
        return ("~/" + s as NSString).expandingTildeInPath
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

    private func browserVerifiedResult(_ actionResult: String) async throws -> ExecResult {
        let page = try await AlakeyaBrowser.shared.readPage()
        return ExecResult(summary: """
        ACTION_RESULT: \(actionResult)
        CURRENT_PAGE: \(String(page.prefix(12_000)))
        """)
    }

    private func runShell(_ command: String) throws -> ExecResult {
        if let blocked = Self.blockedShellReason(command) {
            throw ExecError.failed(blocked)
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", command]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        let startedAt = Date()
        while proc.isRunning && Date().timeIntervalSince(startedAt) < 30 {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            throw ExecError.failed("Команда остановлена по timeout 30 сек.")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        let trimmed = String(out.prefix(12_000))
        if proc.terminationStatus != 0 {
            throw ExecError.failed(trimmed.isEmpty ? "Команда завершилась с ошибкой" : trimmed)
        }
        return ExecResult(summary: """
        SHELL_EXIT_CODE: 0
        COMMAND: \(command)
        OUTPUT:
        \(trimmed.isEmpty ? "(нет вывода)" : trimmed)
        """)
    }

    private static func blockedShellReason(_ command: String) -> String? {
        let lower = command.lowercased()
        let blockedPatterns = [
            #"rm\s+-rf\s+/"#,
            #"sudo\s+rm\s+-rf"#,
            #":\(\)\s*\{\s*:\|:"#,
            #"mkfs\."#,
            #"\bdd\s+if="#,
            #"diskutil\s+erase"#,
            #"csrutil\s+disable"#,
            #"chmod\s+-r\s+777\s+/"#,
            #"chown\s+-r\s+.*\s+/"#,
            #"(curl|wget).*\|\s*(sh|bash|zsh)"#,
        ]
        for pattern in blockedPatterns {
            if lower.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return "Команда заблокирована защитой computer-agent: опасный shell-паттерн."
            }
        }
        return nil
    }
}
