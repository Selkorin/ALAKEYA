import Testing
@testable import Alakeya

@Test
func browserSplitClampsWidthAndPreservesChat() {
    let metrics = BrowserSplitLayout.metrics(
        totalWidth: 1440,
        sidebarWidth: 240,
        requestedBrowserWidth: 900,
        minChatWidth: 420,
        minBrowserWidth: 320,
        splitterWidth: 12
    )

    #expect(metrics.canShowBrowser)
    #expect(metrics.browserWidth == 768)
    #expect(metrics.chatPanelWidth == 660)
}

@Test
func browserSplitHidesWhenWindowCannotFitAllColumns() {
    let metrics = BrowserSplitLayout.metrics(
        totalWidth: 960,
        sidebarWidth: 240,
        requestedBrowserWidth: 460,
        minChatWidth: 420,
        minBrowserWidth: 320,
        splitterWidth: 12
    )

    #expect(!metrics.canShowBrowser)
    #expect(metrics.browserWidth == 0)
    #expect(metrics.chatPanelWidth == 960)
}

@Test
func browserSplitKeepsRequestedWidthInsideSafeRange() {
    let metrics = BrowserSplitLayout.metrics(
        totalWidth: 1200,
        sidebarWidth: 240,
        requestedBrowserWidth: 100,
        minChatWidth: 420,
        minBrowserWidth: 320,
        splitterWidth: 12
    )

    #expect(metrics.canShowBrowser)
    #expect(metrics.browserWidth == 320)
}
