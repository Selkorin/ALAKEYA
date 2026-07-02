import Testing
import Foundation
import AppKit
@testable import Alakeya

@Test
func browserToolNamesAreRegistered() {
    let names = Set(BrowserTools().toolNames)
    #expect(
        names.isSuperset(of: [
            "browser_open",
            "browser_read_page",
            "browser_click",
            "browser_type",
            "browser_back",
            "browser_reload",
            "browser_scroll",
            "browser_select",
            "browser_submit",
            "browser_wait",
            "browser_screenshot",
        ])
    )
}

@Test
func readPageIsLowRisk() {
    let action = BrowserTools().makeAction(
        toolName: "browser_read_page",
        args: [:]
    )
    #expect(action?.type == .browserReadPage)
    #expect(action?.risk == .low)
}

@Test
func clickAndTypeRequireConfirmationInAutoMode() {
    let click = BrowserTools().makeAction(
        toolName: "browser_click",
        args: ["text": "Продолжить"]
    )
    let type = BrowserTools().makeAction(
        toolName: "browser_type",
        args: ["field": "Поиск", "text": "Алакея"]
    )
    #expect(click?.risk == .medium)
    #expect(type?.risk == .medium)
}

@Test
func submitIsAlwaysHighRisk() {
    let action = BrowserTools().makeAction(
        toolName: "browser_submit",
        args: ["element_id": "ak-4"]
    )
    #expect(action?.risk == .high)
    #expect(PolicyEngine.shared.shouldAutoConfirm(action!) == false)
}

@Test
func searchInternetDoesNotRequirePermission() {
    let action = Action(
        type: .searchInternet,
        title: "Поиск",
        description: "Поиск",
        target: "топ 10 отелей Крыма",
        scope: "Research",
        args: ["query": "топ 10 отелей Крыма"]
    )
    #expect(PolicyEngine.shared.shouldAutoConfirm(action) == true)
}

@Test
func passiveBrowserActionsAreLowRisk() {
    for tool in ["browser_scroll", "browser_wait", "browser_screenshot"] {
        let action = BrowserTools().makeAction(toolName: tool, args: [:])
        #expect(action?.risk == .low)
    }
}

@Test @MainActor
func browserCanReadTypeAndClickByElementID() async throws {
    let store = BrowserStore()
    store.webView.loadHTMLString(
        """
        <html><body>
          <input aria-label="Поиск" value="">
          <button onclick="document.querySelector('h1').textContent='Готово'">Продолжить</button>
          <h1>Ожидание</h1>
        </body></html>
        """,
        baseURL: URL(string: "https://example.test")
    )
    try await Task.sleep(nanoseconds: 500_000_000)

    let firstPage = try await store.readPage()
    let root = try #require(
        JSONSerialization.jsonObject(with: Data(firstPage.utf8)) as? [String: Any]
    )
    let elements = try #require(root["elements"] as? [[String: Any]])
    let inputID = try #require(
        elements.first(where: { $0["tag"] as? String == "input" })?["id"] as? String
    )
    let buttonID = try #require(
        elements.first(where: { $0["tag"] as? String == "button" })?["id"] as? String
    )

    _ = try await store.type(text: "Алакея", elementID: inputID, field: "")
    _ = try await store.click(elementID: buttonID, text: "")
    let updatedPage = try await store.readPage()

    #expect(updatedPage.contains("Алакея"))
    #expect(updatedPage.contains("Готово"))
}

@Test @MainActor
func plainBusinessSearchUsesDeterministicPipeline() {
    #expect(ToolRunner.detectScope("Найди 20 салонов красоты в Севастополе") == .localBusinessResearch)
    #expect(ToolRunner.detectScope("Собери 15 стоматологий в Москве в CSV") == .localBusinessResearchThenExport)
}

@Test @MainActor
func internetLookupUsesHeadlessResearchScope() {
    #expect(ToolRunner.detectScope("Найди в интернете последние новости про ИИ") == .research)
    #expect(ToolRunner.detectScope("Проанализируй сайт https://example.com и найди контакты") == .research)
    #expect(ToolRunner.detectScope("Проверь актуальную цену биткоина сегодня") == .research)
    #expect(ToolRunner.detectScope("найди топ 10 отелей Крыма") == .research)
    #expect(ToolRunner.detectScope("найди лучшие гостиницы крыма") == .research)
    #expect(ToolRunner.detectScope("найди номера лучших отелей Крыма 10 штук") == .research)
    #expect(ToolRunner.detectScope("подбери отели в Крыму с бассейном") == .research)
    #expect(ToolRunner.detectScope("посоветуй санатории Крыма для семьи") == .research)
    #expect(ToolRunner.detectScope("рейтинг ресторанов Ялты") == .research)
    #expect(ToolRunner.detectScope("лучшие кафе Севастополя") == .research)
}

@Test @MainActor
func explicitBrowserNavigationStillUsesBrowserScope() {
    #expect(ToolRunner.detectScope("Открой сайт https://example.com") == .browser)
    #expect(ToolRunner.detectScope("Прокрути страницу вниз") == .browser)
    #expect(ToolRunner.detectScope("найди отели в Ялте в 2гис") == .localBusinessResearch)
    #expect(ToolRunner.detectScope("собери контакты отелей Крыма") == .localBusinessResearch)
    #expect(ToolRunner.detectScope("найди телефоны ресторанов Ялты") == .localBusinessResearch)
}

@Test
func hotelSearchSurvivesCityFollowUp() throws {
    let initial = LocalBusinessQuery.parse(from: "привет найди 10 отелей")

    #expect(initial.category == "отели")
    #expect(initial.targetCount == 10)
    #expect(initial.city == nil)

    let city = try #require(LocalBusinessQuery.parseCityContinuation(from: "севастополь"))
    let resumed = initial.resolvingCity(city)

    #expect(resumed.category == "отели")
    #expect(resumed.targetCount == 10)
    #expect(resumed.city == "Севастополь")
}

@Test
func hotelRegionQueriesResolveKnownRegions() {
    let crimea = LocalBusinessQuery.parse(from: "найди контакты отелей крыма")
    #expect(crimea.category == "отели")
    #expect(crimea.city == "Крым")

    let krasnodar = LocalBusinessQuery.parse(from: "собери гостиницы Краснодарского края")
    #expect(krasnodar.city == "Краснодарский край")
}

@Test
func hotelResearchPlanUsesHeadlessSearchInstructions() {
    let plan = SearchQueryPlanner.plan(for: "найди топ 10 отелей Крыма")
    #expect(plan.intent == ResearchIntent.hotelResearch.rawValue)
    #expect(plan.queries.contains { $0.localizedCaseInsensitiveContains("Крым") })
    #expect(plan.instructions.localizedCaseInsensitiveContains("browser_agent_search"))
    #expect(plan.instructions.localizedCaseInsensitiveContains("Не отвечай списком ссылок"))
    #expect(plan.instructions.localizedCaseInsensitiveContains("Телефон/контакты"))
    #expect(plan.instructions.localizedCaseInsensitiveContains("Источники"))
    #expect(!plan.instructions.localizedCaseInsensitiveContains("Выполни каждый запрос в браузере"))
}

@Test
func topAndHotelQueriesUseExtractionSearchMode() {
    #expect(Executors.defaultBrowserAgentSearchMode(
        query: "найди топ 10 отелей Крыма",
        requestedMode: nil
    ) == "search_extract")

    #expect(Executors.defaultBrowserAgentSearchMode(
        query: "подбери лучшие гостиницы в Ялте с бассейном",
        requestedMode: nil
    ) == "search_extract")

    #expect(Executors.defaultBrowserAgentSearchMode(
        query: "курс доллара сегодня",
        requestedMode: nil
    ) == "search")
}

@Test
func unrelatedCommandDoesNotBecomePendingCity() {
    #expect(LocalBusinessQuery.parseCityContinuation(from: "найди теперь рестораны") == nil)
    #expect(LocalBusinessQuery.parseCityContinuation(from: "стоп") == nil)
}

@Test
func businessCardWrapperAndPhoneArraysAreParsed() throws {
    let json = """
    {
      "url": "https://example.test",
      "count": 2,
      "cards": [
        {
          "name": "Салон Лилия",
          "phones": ["+7 978 123-45-67"],
          "ratings": ["4,9 ★"],
          "address": "ул. Ленина, 10",
          "website": "https://lilia.example"
        },
        {
          "name": "Студия Ника",
          "phones": ["8 (978) 555-44-33"],
          "address": "проспект Победы, 2",
          "website": ""
        }
      ]
    }
    """
    let leads = LocalBusinessExtractionNormalizer.parseBusinessCards(
        json,
        source: "Тест",
        sourceURL: "https://example.test",
        city: "Севастополь"
    )
    #expect(leads.count == 2)
    #expect(leads[0].phone == "+7 (978) 123-45-67")
    #expect(leads[0].notes.contains("4,9"))
}

@Test
func localBusinessDropsPhoneOnlyJunkRows() {
    let json = """
    {"phone": "8 (800) 511-06-34", "address": "", "name": ""}
    """
    let leads = LocalBusinessExtractionNormalizer.parseContactCards(
        json,
        source: "Google Поиск",
        sourceURL: "https://google.com/search?q=test",
        city: "Севастополь"
    )
    #expect(leads.isEmpty)
}

@Test
func localBusinessNormalizesRussianPhone() {
    let normalized = LocalBusinessLeadValidator.normalizePhone("89504544661")
    #expect(normalized == "+7 (950) 454-46-61")
    #expect(LocalBusinessLeadValidator.hasUsableName("Google Поиск") == false)
}

@Test
func localBusinessRejectsBotChallengeText() {
    let pageText = """
    Подтвердите, что запросы отправляли вы, а не робот
    +7 (965) 340-98-22
    yandex.ru
    """
    let leads = LocalBusinessExtractionNormalizer.parsePageText(
        pageText,
        source: "Яндекс Карты",
        sourceURL: "https://yandex.ru/maps/?text=отели%20Крым",
        city: "Крым"
    )
    #expect(leads.isEmpty)
    #expect(LocalBusinessLeadValidator.hasUsableName("Подтвердите, что запросы отправляли вы, а не робот") == false)
}

@Test
func defaultLocalBusinessSourcesAvoidYandexMapsFirst() {
    let query = LocalBusinessQuery.parse(from: "выпиши в таблицу 10 отелей Крыма с номерами")
    #expect(query.requestedSources.first == .twoGis)
    #expect(!query.requestedSources.contains(.yandexMaps))
    #expect(!query.requestedSources.contains(.yandexSearch))
}

@Test
func yandexSourcesAreExplicitAndLowIntensity() {
    let query = LocalBusinessQuery.parse(from: "найди отели Крыма в Яндекс Картах")
    #expect(query.requestedSources.contains(.yandexMaps))
    #expect(LocalBusinessSearchSource.yandexMaps.maxScrollAttempts == 1)
    #expect(LocalBusinessSearchSource.yandexSearch.maxScrollAttempts == 1)
    #expect(LocalBusinessSearchSource.twoGis.maxScrollAttempts > 1)
}

@Test
func contactObjectIsParsedAsSingleLead() {
    let json = """
    {
      "name": "Салон Лилия",
      "address": "ул. Ленина, 10",
      "phones": ["+7 978 123-45-67"]
    }
    """
    let leads = LocalBusinessExtractionNormalizer.parseContactCards(
        json,
        source: "Тест",
        sourceURL: "https://example.test",
        city: "Севастополь"
    )
    #expect(leads.count == 1)
    #expect(leads.first?.phone == "+7 (978) 123-45-67")
}

@Test
func annotationAspectFitKeepsImageInsideCanvas() {
    let rect = AnnotationGeometry.aspectFitRect(
        imageSize: CGSize(width: 1600, height: 900),
        containerSize: CGSize(width: 600, height: 600)
    )
    #expect(rect.width == 600)
    #expect(rect.height == 337.5)
    #expect(rect.minY == 131.25)
}

@Test @MainActor
func screenshotImageCanBeCopiedAsPNG() throws {
    let bitmap = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 4,
        pixelsHigh: 4,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ))
    let image = NSImage(size: NSSize(width: 4, height: 4))
    image.addRepresentation(bitmap)

    #expect(BrowserClipboard.copy(image))
    #expect(NSPasteboard.general.data(forType: .png) != nil)
}

@Test
func searchSourcesRequestEnoughResults() {
    let google = LocalBusinessSearchSource.googleSearch
        .url(category: "салоны красоты", city: "Севастополь")?
        .absoluteString ?? ""
    let yandex = LocalBusinessSearchSource.yandexSearch
        .url(category: "салоны красоты", city: "Севастополь")?
        .absoluteString ?? ""

    #expect(google.contains("num=20"))
    #expect(yandex.contains("numdoc=10"))
}

@Test
func sourceQualityScorerPenalizesChallengesAndProducesValidJSON() throws {
    let ranked = SourceQualityScorer.rank([
        (
            url: "https://example-hotel.test/contacts",
            title: "Отель \"Море\" контакты",
            snippet: "Телефон +7 978 123-45-67, рейтинг 4.8, официальный сайт"
        ),
        (
            url: "https://yandex.ru/search/?text=отели",
            title: "Подтвердите, что вы не робот",
            snippet: "captcha access denied"
        ),
    ])

    #expect(ranked.first?.url.contains("example-hotel") == true)
    #expect((ranked.last?.score ?? 100) < 10)

    let json = SourceQualityScorer.rankJSON([
        (url: "https://example-hotel.test", title: "Отель \"Море\"", snippet: "Телефон +7")
    ])
    let decoded = try #require(
        JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]
    )
    #expect(decoded.first?["title"] as? String == "Отель \"Море\"")
}
