import Foundation
import Testing
@testable import Alakeya

@Test
func markdownLinksRenderAsLabelsWithURLAttribute() {
    let rendered = MDInline.buildAttributed(
        "[Топ-отелей в Крыму](https://101hotels.com/russia/region/krym/top_hotels)",
        size: 14
    )

    #expect(String(rendered.characters) == "Топ-отелей в Крыму")
    let links = rendered.runs.compactMap { $0.link }
    #expect(links.first?.absoluteString == "https://101hotels.com/russia/region/krym/top_hotels")
}

@Test
func bareURLsRenderAsShortDomainLinks() {
    let rendered = MDInline.buildAttributed(
        "Источник: https://www.tripadvisor.ru/Hotels-g313972-Crimea-Hotels.html",
        size: 14
    )

    #expect(String(rendered.characters) == "Источник: tripadvisor.ru")
    let links = rendered.runs.compactMap { $0.link }
    #expect(links.first?.absoluteString == "https://www.tripadvisor.ru/Hotels-g313972-Crimea-Hotels.html")
}
