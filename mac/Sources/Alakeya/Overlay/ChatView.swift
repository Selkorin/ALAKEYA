import SwiftUI
import AppKit
import UniformTypeIdentifiers

// ============================================================
// ChatView.swift — main chat window content.
//
// Structure:
//   Top bar:   [● ● ●]  Alakeya  |  Настройки
//   Middle:    messages
//   Input bar: text field | mic | send
// ============================================================

struct ChatView: View {

    @ObservedObject var store: AgentStore
    @ObservedObject var updateManager: UpdateManager
    var onSubmit      : (String, [Data]) -> Void
    var onVoiceStart  : () -> Void
    var onVoiceStop   : () -> Void
    var onClose       : () -> Void
    var onMinimize    : () -> Void = {}
    var onFullscreen  : () -> Void = {}
    var onBrowserToggle: (Bool) -> Void = { _ in }

    @ObservedObject private var browser = AlakeyaBrowser.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var skills = SkillStore.shared
    @ObservedObject private var agentProfiles = AgentProfileStore.shared
    @ObservedObject private var socialTargets = SocialPublishingTargetStore.shared
    @State private var text            = ""
    @State private var attachments     : [URL] = []
    @State private var previewImage    : NSImage? = nil
    @State private var isDragTargeted  = false
    @State private var inputTextHeight : CGFloat = 36
    @State private var sidebarOpen     = false
    @State private var agentsOpen      = false
    @State private var settingsTab     = "appearance"
    @State private var showsCreateAgent = false
    @State private var showsProfilePanel = false
    @State private var showsComposerMenu = false
    @State private var showsSocialComposer = false
    @State private var showsPublishPlanner = false
    @State private var showsDesignWorkspace = false
    @StateObject private var designWorkspace = DesignWorkspaceModel()
    @State private var navigationExpanded = true
    @FocusState private var focused    : Bool

    // Traffic lights hover
    @State private var hoveringLights = false

    // Scroll to bottom button
    @State private var showScrollToBottom = false
    @State private var isNearBottom = true

    // ── Browser split layout ──────────────────────────────
    // Constraints (px)
    private let kMinBrowserWidth:     CGFloat = 520
    // This is the whole chat side, including the 240 pt agent sidebar.
    // Reserving only the conversation width used to collapse messages to a
    // narrow strip whenever an old, oversized browser width was restored.
    private let kMinChatPanelWidth:   CGFloat = 560
    private let kIdealChatPanelWidth: CGFloat = 720
    private let kDefaultBrowserWidth: CGFloat = 720
    private let kMaxBrowserWidth:     CGFloat = 920
    private let kDividerHitWidth:     CGFloat = 12    // comfortable hit area

    // Persisted sidebar width (UserDefaults)
    @AppStorage("browserSidebarWidth") private var savedBrowserWidth: Double = 600

    // Live width used during the session — initialized from savedBrowserWidth on appear
    @State private var browserWidth: CGFloat = 600

    // Drag + hover state
    @State private var isDraggingDivider  = false
    @State private var dividerDragStart:   CGFloat = 0
    @State private var isDividerHovered   = false

    private var isListening: Bool { store.status == .listening }
    // One source of truth: the header button always controls the rail.
    // Individual workspaces handle narrow widths internally.
    private var showsExpandedNavigation: Bool { navigationExpanded }

    // ── Root ─────────────────────────────────────────────

    var body: some View {
        ZStack {
            // ── TopBar (full width) + content row ─────────
            VStack(spacing: 0) {
                topBar
                    .zIndex(1)
                GeometryReader { geo in
                    let metrics = splitMetrics(totalWidth: geo.size.width)
                    let maxBW = maxBrowserWidth(totalWidth: geo.size.width)
                    let browserPanelWidth = browser.isPresented && metrics.canShowBrowser
                        ? metrics.browserWidth + kDividerHitWidth
                        : 0

                    HStack(spacing: 0) {
                        // ── Chat area — always fills remaining space ───────
                        HStack(spacing: 0) {
                            if navigationExpanded {
                                AgentSidebarView(
                                    store: store,
                                    agentsOpen: $agentsOpen,
                                    sidebarOpen: $sidebarOpen,
                                    showsExpandedNavigation: showsExpandedNavigation,
                                    onStartChat: {}
                                )
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                            if sidebarOpen {
                                SidebarView(store: store, isOpen: $sidebarOpen)
                                    .transition(.opacity)
                            }
                            VStack(spacing: 0) {
                                if store.showSettings {
                                    SettingsView(
                                        store: store,
                                        updateManager: updateManager,
                                        onClose: { store.showSettings = false },
                                        tab: $settingsTab
                                    )
                                } else if agentsOpen {
                                    AgentWorkspaceView(store: store) {
                                        agentsOpen = false
                                    }
                                } else {
                                    GeometryReader { contentGeo in
                                        VStack(spacing: 0) {
                                            middleArea(chatW: contentGeo.size.width)
                                            inputBar(chatW: contentGeo.size.width)
                                        }
                                    }
                                }
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(0)

                        // ── Resizable browser panel — always in hierarchy ──
                        // WKWebView never removed → page state survives show/hide/resize.
                        HStack(spacing: 0) {
                            // Draggable divider: 10 px hit area, 1 px visual line.
                            // Hover → highlight + resize cursor.
                            // Double-click → reset to default width.
                            ZStack {
                                Rectangle()
                                    .fill((isDraggingDivider || isDividerHovered)
                                          ? WAI.accent.opacity(0.45)
                                          : Color.white.opacity(0.08))
                                    .frame(width: 1)
                            }
                            .frame(width: kDividerHitWidth)
                            .contentShape(Rectangle())
                            .onHover { inside in
                                isDividerHovered = inside
                                if inside { NSCursor.resizeLeftRight.push() }
                                else      { NSCursor.pop() }
                            }
                            .onTapGesture(count: 2) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    browserWidth = min(kDefaultBrowserWidth, maxBW)
                                }
                                savedBrowserWidth = Double(browserWidth)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        if !isDraggingDivider {
                                            isDraggingDivider = true
                                            dividerDragStart  = browserWidth
                                        }
                                        let newW = dividerDragStart - value.translation.width
                                        browserWidth = max(kMinBrowserWidth, min(maxBW, newW))
                                        #if DEBUG
                                        let chatW = geo.size.width - browserWidth - kDividerHitWidth
                                        print("[Split] avail=\(Int(geo.size.width)) chat=\(Int(chatW)) browser=\(Int(browserWidth)) maxBW=\(Int(maxBW))")
                                        #endif
                                    }
                                    .onEnded { _ in
                                        isDraggingDivider = false
                                        savedBrowserWidth = Double(browserWidth)
                                    }
                            )

                            BrowserPaneView(store: browser.store)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(
                            width: browserPanelWidth,
                            alignment: .leading
                        )
                        .clipped()
                    }
                    .onChange(of: geo.size) { _, newSize in
                        let clampedMax = maxBrowserWidth(totalWidth: newSize.width)
                        if clampedMax >= kMinBrowserWidth && browserWidth > clampedMax {
                            browserWidth = clampedMax
                            savedBrowserWidth = Double(clampedMax)
                        }
                        #if DEBUG
                        let mBW = clampedMax
                        let eBW = splitMetrics(totalWidth: newSize.width).browserWidth
                        let cW  = newSize.width - (browser.isPresented ? eBW + kDividerHitWidth : 0)
                        print("[Layout] avail=\(Int(newSize.width))×\(Int(newSize.height)) chatW=\(Int(cW)) browserW=\(Int(eBW)) maxBW=\(Int(mBW)) browser=\(browser.isPresented)")
                        #endif
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Full-screen image preview overlay ─────────
            if showsDesignWorkspace {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.18)) { showsDesignWorkspace = false }
                    }

                DesignWorkspaceView(
                    store: store,
                    model: designWorkspace,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.18)) { showsDesignWorkspace = false }
                    }
                )
                .frame(width: 980, height: 680)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WAI.accentBright.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
                .padding(28)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(30)
            }

            if let img = previewImage {
                Color.black.opacity(0.78)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { previewImage = nil }
                    }

                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(32)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .onAppear {
            focused = true
            let restored = CGFloat(savedBrowserWidth)
            browserWidth = restored.isFinite
                && restored >= kMinBrowserWidth
                && restored <= kMaxBrowserWidth
                ? restored
                : kDefaultBrowserWidth
            savedBrowserWidth = Double(browserWidth)
            agentProfiles.reload()
        }
        .onChange(of: browser.isPresented) { _, isPresented in
            onBrowserToggle(isPresented)
        }
        .sheet(isPresented: $showsCreateAgent) {
            CreateAgentSheet(store: store) { profile, avatarData in
                if let avatarData {
                    try? profiles.setAgentAvatar(avatarData, agentID: profile.id)
                }
                activateAgent(profile.id)
                showsCreateAgent = false
                agentsOpen = true
            }
        }
        .sheet(isPresented: $showsProfilePanel) {
            ProfileSettingsSheet(store: store, onClose: { showsProfilePanel = false })
        }
        .sheet(isPresented: $showsSocialComposer) {
            SocialComposerSheet(
                targetStore: socialTargets,
                onOpenConnectors: openConnectorsSettings
            )
        }
        .sheet(isPresented: $showsPublishPlanner) {
            PublishPlannerSheet(onInsert: insertComposerText)
        }
    }

    private func reservedChatWidth(totalWidth: CGFloat) -> CGFloat {
        min(kIdealChatPanelWidth, max(kMinChatPanelWidth, totalWidth * 0.42))
    }

    private func maxBrowserWidth(totalWidth: CGFloat) -> CGFloat {
        min(kMaxBrowserWidth, max(0, totalWidth - reservedChatWidth(totalWidth: totalWidth) - kDividerHitWidth))
    }

    private func splitMetrics(totalWidth: CGFloat) -> BrowserSplitLayout.Metrics {
        BrowserSplitLayout.metrics(
            totalWidth: totalWidth,
            sidebarWidth: 0,
            requestedBrowserWidth: min(browserWidth, kMaxBrowserWidth),
            minChatWidth: reservedChatWidth(totalWidth: totalWidth),
            minBrowserWidth: kMinBrowserWidth,
            splitterWidth: kDividerHitWidth
        )
    }
    // ── Background ────────────────────────────────────────

    private var windowBackground: some View {
        WAI.canvas
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // ── Top bar ───────────────────────────────────────────

    private var topBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Traffic lights
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.27, blue: 0.23))
                    .frame(width: 12, height: 12)
                    .onTapGesture { onClose() }
                Circle().fill(Color(red: 1, green: 0.76, blue: 0.18))
                    .frame(width: 12, height: 12)
                    .onTapGesture { onMinimize() }
                Circle().fill(Color(red: 0.20, green: 0.85, blue: 0.33))
                    .frame(width: 12, height: 12)
                    .onTapGesture { onFullscreen() }
            }
            .padding(.leading, 10)
            .onHover { hoveringLights = $0 }

            // Sidebar toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    navigationExpanded.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(navigationExpanded ? WAI.accentBright : WAI.textDim)
            }
            .buttonStyle(.plain)
            .help(navigationExpanded ? "Скрыть боковую панель" : "Показать боковую панель")
            .padding(.leading, 10)

            Spacer()

            Text(screenTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WAI.textDim)

            Spacer()

            Button {
                NotificationCenter.default.post(name: .alakeyaShowVoiceOrb, object: nil)
            } label: {
                personaAsset(size: 24)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(
                            isListening ? WAI.accentSoft : WAI.surfaceInset
                        )
                    )
                    .overlay(
                        Circle().stroke(
                            isListening ? WAI.lineAccent : WAI.line,
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
            .help("Вызвать персонажа")
            .accessibilityLabel("Вызвать персонажа")
            .padding(.trailing, 8)

            // Browser toggle
            Button {
                if browser.isPresented {
                    AlakeyaBrowser.shared.close()
                } else {
                    AlakeyaBrowser.shared.open()
                }
            } label: {
                Image(systemName: browser.isPresented ? "globe.desk.fill" : "globe.desk")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(browser.isPresented ? WAI.accentBright : WAI.textDim)
            }
            .buttonStyle(.plain)
            .help(browser.isPresented ? "Закрыть браузер" : "Открыть браузер")
            .padding(.trailing, 12)
        }
        .frame(height: 44)
        .background(WAI.surfaceStrong)
        .overlay(Rectangle().fill(WAI.line).frame(height: 1), alignment: .bottom)
    }

    private var screenTitle: String {
        if store.showSettings { return "Центр управления" }
        if agentsOpen { return "Мои агенты" }
        if sidebarOpen { return "История" }
        return store.sessions.first(where: { $0.id == store.activeSessionID })?.title
            ?? activeAssistantName
    }

    // ── Middle area (messages) ────────────────────────────

    private func middleArea(chatW: CGFloat) -> some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                if isFreshChat {
                    chatEmptyState
                        .frame(maxWidth: .infinity)
                        .frame(height: geo.size.height)
                } else {
                    ZStack(alignment: .leading) {
                        ScrollView(.vertical, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 0) {
                                Spacer(minLength: 0)
                                LazyVStack(alignment: .leading, spacing: 18) {
                                    ForEach(store.messages) { msg in
                                        MessageBubbleView(
                                            message: msg,
                                            chatWidth: chatW,
                                            userName: profiles.user.name,
                                            userAvatar: profiles.userAvatar(),
                                            assistantName: activeAssistantName,
                                            assistantAvatar: profiles.agentAvatar(
                                                for: store.settings.models.activeSkillID
                                            )
                                        ) { img in
                                            withAnimation(.easeOut(duration: 0.2)) { previewImage = img }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    if let status = store.toolStatus {
                                        ToolStatusBubbleView(
                                            status: status,
                                            assistantName: activeAssistantName,
                                            assistantAvatar: profiles.agentAvatar(
                                                for: store.settings.models.activeSkillID
                                            )
                                        )
                                        .frame(maxWidth: .infinity)
                                        .id("tool-status")
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom")
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 28)
                                .frame(width: min(760, max(320, chatW)), alignment: .topLeading)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                            .background(alignment: .topLeading) {
                                ScrollPositionObserver { shouldShow in
                                    let nextIsNearBottom = !shouldShow
                                    if isNearBottom != nextIsNearBottom {
                                        isNearBottom = nextIsNearBottom
                                    }
                                    if showScrollToBottom != shouldShow {
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            showScrollToBottom = shouldShow
                                        }
                                    }
                                }
                                .frame(width: 1, height: 1)
                                .allowsHitTesting(false)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isDragTargeted ? WAI.accentSoft.opacity(0.15) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isDragTargeted ? WAI.accentBright.opacity(0.4) : Color.clear, lineWidth: 2)
                                )
                        )
                        .coordinateSpace(name: "scrollSpace")
                        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                            handleDrop(providers: providers)
                            return true
                        }

                        ScrollActivityObserver { shouldShow in
                            let nextIsNearBottom = !shouldShow
                            if isNearBottom != nextIsNearBottom {
                                isNearBottom = nextIsNearBottom
                            }
                            if showScrollToBottom != shouldShow {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showScrollToBottom = shouldShow
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)

                        if showScrollToBottom {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    scrollToBottomButton(proxy: proxy) { reachedBottom in
                                        isNearBottom = reachedBottom
                                        if reachedBottom {
                                            withAnimation(.easeOut(duration: 0.18)) {
                                                showScrollToBottom = false
                                            }
                                        } else if !showScrollToBottom {
                                            withAnimation(.easeOut(duration: 0.18)) {
                                                showScrollToBottom = true
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 18)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .zIndex(20)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom")
                            isNearBottom = true
                            showScrollToBottom = false
                        }
                    }
                    .onChange(of: store.messages.count) { _, _ in
                        if isNearBottom {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                                showScrollToBottom = false
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showScrollToBottom = true
                            }
                        }
                    }
                    .onChange(of: store.toolStatus) { _, _ in
                        if isNearBottom {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("tool-status", anchor: .bottom)
                                showScrollToBottom = false
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showScrollToBottom = true
                            }
                        }
                    }
                }
            }
        }
    }

    private var isFreshChat: Bool {
        !store.messages.contains(where: { $0.role == .user })
    }

    private var activeAssistantName: String {
        if store.settings.models.activeSkillID == "general" { return "Алакея" }
        return agentProfiles.profile(for: store.settings.models.activeSkillID)?.name
            ?? skills.availableSkills.first(
                where: { $0.id == store.settings.models.activeSkillID }
            )?.title
            ?? "Алакея"
    }

    private var activeAgentRoleLabel: String {
        if store.settings.models.activeSkillID == "general" { return "помощник" }
        return agentProfiles.profile(for: store.settings.models.activeSkillID)?.roleLabel
            ?? "помощник"
    }

    private var welcomeTitle: String {
        "Привет, я твой \(activeAgentRoleLabel)."
    }

    private var chatEmptyState: some View {
        GeometryReader { geo in
            let compactHeight = geo.size.height < 590
            let compactWidth = geo.size.width < 720
            let heroSize: CGFloat = compactHeight ? 72 : (compactWidth ? 88 : 104)
            let columnCount = geo.size.width >= 900 ? 3 : (geo.size.width >= 560 ? 2 : 1)
            let actionColumns = Array(
                repeating: GridItem(.flexible(minimum: 150, maximum: 280), spacing: 10),
                count: columnCount
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    welcomeAvatar(size: heroSize)
                        .frame(width: heroSize, height: heroSize)
                        .padding(.top, compactHeight ? 6 : 14)

                    Text(welcomeTitle)
                        .font(.system(size: compactHeight ? 21 : 25, weight: .semibold))
                        .foregroundStyle(WAI.text)
                        .padding(.top, compactHeight ? 8 : 12)
                        .multilineTextAlignment(.center)

                    Text("Чем займёмся сегодня?")
                        .font(.system(size: compactHeight ? 14 : 17))
                        .foregroundStyle(WAI.textMuted)
                        .padding(.top, 6)

                    LazyVGrid(
                        columns: actionColumns,
                        spacing: 10
                    ) {
                        quickAction("lightbulb", "Придумать идею") { text = "Помоги придумать идею для " }
                        quickAction("photo", "Создать изображение") { showsDesignWorkspace = true }
                        quickAction("pencil", "Написать текст") { text = "Напиши текст для " }
                        quickAction("magnifyingglass", "Поиск в интернете") { text = "Найди информацию: " }
                        quickAction("doc.text", "Создать документ") { text = "Создай документ: " }
                        quickAction("wrench", "Анализ данных") { text = "Проанализируй данные: " }
                    }
                    .padding(.top, compactHeight ? 12 : 20)
                    .frame(maxWidth: columnCount == 3 ? 840 : (columnCount == 2 ? 560 : 300))
                }
                .padding(.horizontal, compactWidth ? 16 : 28)
                .padding(.bottom, compactHeight ? 10 : 18)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
    }

    private func quickAction(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(WAI.accentBright)
                    .frame(height: 22)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(WAI.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(WAI.surfaceInset)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(WAI.line, lineWidth: 0.5))
            )
        }
        .buttonStyle(QuickActionButtonStyle())
    }

    @ViewBuilder
    private func welcomeAvatar(size: CGFloat) -> some View {
        if let image = profiles.agentAvatar(for: store.settings.models.activeSkillID) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(WAI.lineAccent, lineWidth: 1)
                )
                .shadow(color: WAI.accentGlow.opacity(0.24), radius: 14)
        } else {
            OrbView(
                state: store.assistantState,
                emotion: store.orbEmotion,
                size: size
            )
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func personaAsset(size: CGFloat) -> some View {
        if let url = Bundle.module.url(forResource: "pers_1", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(WAI.accentBright)
        }
    }

    // ── Input bar ─────────────────────────────────────────

    private func inputBar(chatW: CGFloat) -> some View {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let canSend = hasText || !attachments.isEmpty
        let maxInputWidth = min(760, max(280, chatW - 48))
        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 9) {
                if !attachments.isEmpty {
                    attachmentPreviewStrip
                }
                if !socialTargets.selectedTargets().isEmpty {
                    selectedSocialTargetsStrip
                }

                HStack(spacing: 10) {
                    composerPlusButton

                    TextField("Напишите сообщение...", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(WAI.text)
                        .focused($focused)
                        .lineLimit(1...6)
                        .onSubmit { sendMessage() }

                    Button {
                        if canSend {
                            if isListening { onVoiceStop() }
                            sendMessage()
                        } else {
                            isListening ? onVoiceStop() : onVoiceStart()
                        }
                    } label: {
                        Image(systemName: canSend ? "arrow.up" : (isListening ? "waveform" : "mic.fill"))
                            .font(.system(size: canSend ? 14 : 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color(hex: 0x1D9BF0)))
                            .overlay(Circle().stroke(Color(hex: 0x4DB8FF).opacity(0.55), lineWidth: 1))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .help(canSend ? "Отправить" : (isListening ? "Остановить запись" : "Голосовой режим"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: maxInputWidth)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(WAI.control)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(inputAccentColor, lineWidth: focused || showsComposerMenu || !attachments.isEmpty ? 1.4 : 1)
                    )
            )
            .shadow(color: WAI.accentGlow.opacity(focused || showsComposerMenu ? 0.20 : 0.10), radius: 14, y: 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(WAI.canvas)
    }

    private var inputAccentColor: Color {
        focused || showsComposerMenu || !attachments.isEmpty
            ? WAI.accentBright.opacity(0.72)
            : WAI.lineAccent
    }

    private var composerPlusButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                showsComposerMenu.toggle()
            }
        } label: {
            Image(systemName: showsComposerMenu ? "xmark" : "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(showsComposerMenu ? WAI.accentBright : WAI.textDim)
                .frame(width: 34, height: 34)
                .background(showsComposerMenu ? WAI.accentSoft : WAI.surfaceInset)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(showsComposerMenu ? WAI.accentBright.opacity(0.6) : WAI.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help("Добавить")
        .accessibilityLabel("Открыть меню добавления")
        .overlay(alignment: .bottomLeading) {
            if showsComposerMenu {
            ComposerActionMenu(
                targetStore: socialTargets,
                onConnectors: {
                    showsComposerMenu = false
                    openConnectorsSettings()
                },
                onAttach: {
                    showsComposerMenu = false
                    openAttachmentPanel()
                },
                onSocial: {
                    showsComposerMenu = false
                    showsSocialComposer = true
                },
                onToggleSocialTarget: { target in
                    let selected = socialTargets.selectedIDs().contains(target.id)
                    socialTargets.setSelected(target.id, selected: !selected)
                    showsComposerMenu = false
                }
            )
            .offset(x: -6, y: -48)
            .zIndex(20)
            }
        }
    }

    private var attachmentPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(attachments.enumerated()), id: \.offset) { index, url in
                    attachmentPreview(url: url, index: index)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func attachmentPreview(url: URL, index: Int) -> some View {
        if isImageAttachment(url), let image = NSImage(contentsOf: url) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 84, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(WAI.accentBright.opacity(0.35), lineWidth: 1)
                    )
                Button {
                    attachments.remove(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.94)))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }
            .help(url.lastPathComponent)
        } else {
            HStack(spacing: 6) {
                Image(systemName: attachmentIcon(for: url))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WAI.accentBright)
                Text(url.lastPathComponent)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(WAI.textDim)
                    .lineLimit(1)
                Button {
                    attachments.remove(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(WAI.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(WAI.accentSoft)
            .overlay(Capsule().stroke(WAI.accentBright.opacity(0.28), lineWidth: 1))
            .clipShape(Capsule())
        }
    }

    private var selectedSocialTargetsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(socialTargets.selectedTargets()) { target in
                    HStack(spacing: 6) {
                        Image(systemName: target.connectorID == "telegram" ? "paperplane.fill" : "bubble.left.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(WAI.accentBright)
                        Text("\(target.title) · \(target.destination)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(WAI.textDim)
                            .lineLimit(1)
                        Button {
                            socialTargets.setSelected(target.id, selected: false)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(WAI.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(WAI.accentSoft)
                    .overlay(Capsule().stroke(WAI.accentBright.opacity(0.28), lineWidth: 1))
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── Actions ───────────────────────────────────────────

    private func sendMessage() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty || !attachments.isEmpty else { return }
        let selectedAttachments = attachments
        let imageData = selectedAttachments.compactMap { imageDataForAttachment($0) }
        var messageText = t
        if messageText.isEmpty {
            messageText = imageData.isEmpty ? "Прикрепил файлы." : "Проанализируй прикрепленное изображение."
        }
        let nonImageAttachments = selectedAttachments.filter { !isImageAttachment($0) }
        if !nonImageAttachments.isEmpty {
            let files = nonImageAttachments
                .map { "- \($0.lastPathComponent): \($0.path)" }
                .joined(separator: "\n")
            messageText += "\n\nПрикреплены файлы:\n\(files)"
        }
        let targets = socialTargets.selectedTargets()
        if !targets.isEmpty {
            let targetLines = targets
                .map { target in
                    if let style = SocialPublishingTargetStore.styleSummary(for: target) {
                        return "- \(target.connectorID): \(target.destination) (\(style))"
                    }
                    return "- \(target.connectorID): \(target.destination)"
                }
                .joined(separator: "\n")
            messageText += "\n\nАктивные соцсети для публикации:\n\(targetLines)"
        }
        store.appendMessage(ChatMessage(role: .user, content: messageText, images: imageData))
        text = ""
        attachments = []
        onSubmit(messageText, imageData)
        for target in targets {
            socialTargets.setSelected(target.id, selected: false)
        }
    }

    private func activateAgent(_ id: String) {
        store.newChat(agentId: id)
        agentsOpen = false
        sidebarOpen = false
        store.showSettings = false
    }

    private func openConnectorsSettings() {
        settingsTab = "connectors"
        agentsOpen = false
        sidebarOpen = false
        store.showSettings = true
    }

    private func insertComposerText(_ value: String) {
        text = value
        focused = true
    }

    private func openAttachmentPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .image,
            .pdf,
            .plainText,
            .text,
            .commaSeparatedText,
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "docx"),
            UTType(filenameExtension: "xlsx"),
        ].compactMap { $0 }
        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in
                let merged = attachments + urls
                var seen = Set<String>()
                attachments = merged.filter { seen.insert($0.path).inserted }
                focused = true
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                    do {
                        let itemData = try await provider.loadItem(forTypeIdentifier: "public.file-url", options: nil)
                        if let data = itemData as? Data,
                           let url = URL(dataRepresentation: data, relativeTo: nil) {
                            urls.append(url)
                        }
                    } catch {
                        continue
                    }
                } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                    do {
                        let item = try await provider.loadItem(forTypeIdentifier: "public.image", options: nil)
                        if let image = item as? NSImage,
                           let tiff = image.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiff) {
                            if let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dropped_image_\(UUID().uuidString).jpg")
                                try? jpeg.write(to: tempURL)
                                urls.append(tempURL)
                            }
                        }
                    } catch {
                        continue
                    }
                }
            }

            guard !urls.isEmpty else { return }

            let merged = attachments + urls
            var seen = Set<String>()
            attachments = merged.filter { seen.insert($0.path).inserted }
            focused = true
        }
    }

    private func attachmentIcon(for url: URL) -> String {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return "doc"
        }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .text) { return "doc.text" }
        return "paperclip"
    }

    private func isImageAttachment(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        return type.conforms(to: .image)
    }

    private func imageDataForAttachment(_ url: URL) -> Data? {
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }
}

// ── Private helpers ───────────────────────────────────────

private struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

private struct ComposerActionMenu: View {
    @ObservedObject var targetStore: SocialPublishingTargetStore
    var onConnectors: () -> Void
    var onAttach: () -> Void
    var onSocial: () -> Void
    var onToggleSocialTarget: (SocialPublishingTarget) -> Void
    @State private var socialHovered = false
    @State private var socialSubmenuHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 6) {
                ComposerMenuRow(
                    icon: "puzzlepiece.extension.fill",
                    title: "Коннекторы",
                    subtitle: "Аккаунты, сервисы, доступы",
                    action: onConnectors
                )
                ComposerMenuRow(
                    icon: "paperclip",
                    title: "Прикрепить файл",
                    subtitle: "Фото, PDF, документы, таблицы",
                    action: onAttach
                )
                ComposerMenuRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Соц.сети",
                    subtitle: socialSubtitle,
                    action: onSocial
                )
                .onHover { socialHovered = $0 }
            }
            .padding(8)
            .frame(width: 286)
            .background(menuBackground)
            .shadow(color: WAI.accentGlow.opacity(0.20), radius: 18, y: 6)

            if socialHovered || socialSubmenuHovered {
                SocialTargetsSubmenu(
                    targetStore: targetStore,
                    onOpenSocial: onSocial,
                    onToggleTarget: onToggleSocialTarget
                )
                .onHover { socialSubmenuHovered = $0 }
                .offset(x: 278, y: 0)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeOut(duration: 0.14), value: socialHovered || socialSubmenuHovered)
    }

    private var socialSubtitle: String {
        let count = targetStore.connectedTargets().count
        return count == 0 ? "Добавить канал" : "\(count) подключено"
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(hex: 0x0B0E16))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WAI.accentBright.opacity(0.48), lineWidth: 1)
            )
    }
}

private struct SocialTargetsSubmenu: View {
    @ObservedObject var targetStore: SocialPublishingTargetStore
    var onOpenSocial: () -> Void
    var onToggleTarget: (SocialPublishingTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let targets = targetStore.connectedTargets()
            if targets.isEmpty {
                Text("Нет добавленных соцсетей")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(WAI.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ForEach(targets) { target in
                    let selected = targetStore.selectedIDs().contains(target.id)
                    Button {
                        onToggleTarget(target)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(selected ? WAI.success : WAI.accentBright)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(target.title)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(WAI.text)
                                Text(target.destination)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(WAI.textMuted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selected ? WAI.accentSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(WAI.line)

            Button(action: onOpenSocial) {
                Label("Добавить соцсеть", systemImage: "plus.circle.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(WAI.accentBright)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .frame(width: 232)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0x0B0E16))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(WAI.accentBright.opacity(0.48), lineWidth: 1)
                )
        )
        .shadow(color: WAI.accentGlow.opacity(0.20), radius: 18, y: 6)
    }
}

private struct ComposerMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WAI.accentBright)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(WAI.accentSoft)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(WAI.text)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(WAI.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WAI.textFaint)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovered ? WAI.controlHover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(hovered ? WAI.lineAccent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct SocialComposerSheet: View {
    @ObservedObject var targetStore: SocialPublishingTargetStore
    var onOpenConnectors: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newTelegramDestination = ""
    @State private var statusMessage = ""
    @State private var isAdding = false

    var body: some View {
        ComposerSheetShell(
            title: "Соц.сети",
            icon: "bubble.left.and.bubble.right.fill"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                let connectedTargets = targetStore.connectedTargets()
                if connectedTargets.isEmpty {
                    Text("Нет закрепленных целей. Добавьте Telegram-группу или канал: после проверки он закрепится снизу поля ввода.")
                        .font(.system(size: 12))
                        .foregroundStyle(WAI.textMuted)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(connectedTargets) { target in
                            let selected = targetStore.selectedIDs().contains(target.id)
                            Button {
                                targetStore.setSelected(target.id, selected: !selected)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected ? WAI.accentBright : WAI.textMuted)
                                    Text(target.title)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(WAI.text)
                                    Text(target.destination)
                                        .font(.system(size: 12))
                                        .foregroundStyle(WAI.textMuted)
                                    Spacer()
                                    Button {
                                        targetStore.remove(target)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(WAI.textMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(selected ? WAI.accentSoft : WAI.surfaceInset)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 8) {
                    composerField("Добавить Telegram @группу или chat_id", text: $newTelegramDestination, icon: "at")
                    Button {
                        addTelegramTarget()
                    } label: {
                        Image(systemName: isAdding ? "hourglass" : "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(WAI.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdding)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(WAI.warning)
                }

                HStack(spacing: 10) {
                    Button {
                        onOpenConnectors()
                        dismiss()
                    } label: {
                        Label("Коннекторы", systemImage: "puzzlepiece.extension.fill")
                    }
                    .buttonStyle(ComposerSheetSecondaryButtonStyle())

                    Spacer()
                }
            }
        }
    }

    private func composerField(_ title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WAI.accentBright)
                .frame(width: 18)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .foregroundStyle(WAI.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WAI.control)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(WAI.line, lineWidth: 1))
        )
    }

    private func addTelegramTarget() {
        let destination = SocialPublishingTargetStore.normalizedDestination(
            connectorID: "telegram",
            destination: newTelegramDestination
        )
        guard !destination.isEmpty else { return }
        statusMessage = ""
        isAdding = true

        Task { @MainActor in
            do {
                try await validateTelegramDestination(destination)
                targetStore.upsert(connectorID: "telegram", title: "Telegram", destination: destination)
                if let target = targetStore.connectedTargets().first(where: {
                    $0.connectorID == "telegram" && $0.destination.lowercased() == destination.lowercased()
                }) {
                    targetStore.setSelected(target.id, selected: true)
                    targetStore.markValidated(connectorID: "telegram", destination: destination)
                }
                newTelegramDestination = ""
                isAdding = false
                statusMessage = "Добавлено и закреплено: \(destination)"
            } catch {
                statusMessage = "Telegram недоступен для \(destination): \(error.localizedDescription)"
                isAdding = false
            }
        }
    }

    private func validateTelegramDestination(_ destination: String) async throws {
        guard let token = ConnectorAuthStore.shared.loadToken(for: "telegram"), !token.isEmpty else {
            throw NSError(
                domain: "Alakeya.Telegram",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "бот не подключен в коннекторах"]
            )
        }
        guard let encodedChat = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.telegram.org/bot\(token)/getChat?chat_id=\(encodedChat)") else {
            throw NSError(
                domain: "Alakeya.Telegram",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "некорректный адрес группы"]
            )
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let apiMessage = Self.telegramErrorMessage(from: data)
            throw NSError(
                domain: "Alakeya.Telegram",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: apiMessage ?? "бот не видит эту группу или не имеет прав"]
            )
        }
    }

    private static func telegramErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["description"] as? String
    }
}

private struct PublishPlannerSheet: View {
    var onInsert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var platform = "Telegram"
    @State private var destination = ""
    @State private var publishDate = Date().addingTimeInterval(3600)
    @State private var content = ""

    private let platforms = ["Telegram", "VK", "Instagram", "YouTube", "LinkedIn"]

    var body: some View {
        ComposerSheetShell(
            title: "Планировщик",
            icon: "calendar.badge.clock"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Площадка", selection: $platform) {
                    ForEach(platforms, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 9) {
                    Image(systemName: "at")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WAI.accentBright)
                        .frame(width: 18)
                    TextField("Канал или аккаунт", text: $destination)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(WAI.control)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(WAI.line, lineWidth: 1))
                )

                DatePicker(
                    "Когда",
                    selection: $publishDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(WAI.textDim)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(WAI.control)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(WAI.line, lineWidth: 1))
                )

                TextEditor(text: $content)
                    .font(.system(size: 13.5))
                    .foregroundStyle(WAI.text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(WAI.control)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(WAI.line, lineWidth: 1))
                    )

                HStack {
                    Spacer()
                    Button {
                        onInsert(buildPrompt())
                        dismiss()
                    } label: {
                        Label("Вставить", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(ComposerSheetPrimaryButtonStyle())
                }
            }
        }
    }

    private func buildPrompt() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var parts = ["Запланируй публикацию для \(platform)."]
        let cleanDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanDestination.isEmpty { parts.append("Куда: \(cleanDestination).") }
        parts.append("Когда: \(formatter.string(from: publishDate)).")
        if !cleanContent.isEmpty { parts.append("Контент: \(cleanContent)") }
        parts.append("Собери план публикации, чеклист подготовки и напоминание о финальной проверке.")
        return parts.joined(separator: "\n")
    }
}

private struct ComposerSheetShell<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WAI.accentBright)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(WAI.accentSoft))
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(WAI.text)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WAI.textDim)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 9).fill(WAI.surfaceInset))
                }
                .buttonStyle(.plain)
                .help("Закрыть")
            }

            content
        }
        .padding(20)
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x0B0E16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(WAI.accentBright.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

private struct ComposerSheetPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(hex: 0x001018))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(WAI.accentBright.opacity(configuration.isPressed ? 0.78 : 1))
            )
    }
}

private struct ComposerSheetSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(WAI.textDim)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? WAI.controlHover : WAI.surfaceInset)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(WAI.line, lineWidth: 1))
            )
    }
}

private struct ToolStatusBubbleView: View {
    let status: String
    var assistantName: String
    var assistantAvatar: NSImage?

    private var isImageGeneration: Bool {
        let lower = status.lowercased()
        // More precise check - must start with generating and contain image keywords
        return lower.hasPrefix("генерирую изображение") ||
               lower.hasPrefix("генерирую фото") ||
               (lower.hasPrefix("генерирую") && (lower.contains("изображен") || lower.contains("картинк") || lower.contains("арт")))
    }

    var body: some View {
        if isImageGeneration {
            imageGenerationStatus
        } else {
            standardStatus
        }
    }

    private var standardStatus: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let shimmerX = CGFloat((t.truncatingRemainder(dividingBy: 1.6)) / 1.6)
            HStack(spacing: 8) {
                Image(systemName: phase.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(phase.color)
                    .frame(width: 18)
                Text(status)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WAI.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0x0B0E16).opacity(0.82))
                    .overlay(
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    phase.color.opacity(0.18),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 0.42)
                            .offset(x: -geo.size.width * 0.45 + shimmerX * geo.size.width * 1.35)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(phase.color.opacity(0.20), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(.vertical, 2)
    }

    private var imageGenerationStatus: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(generationStatusText)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(WAI.text)
                    Text("Генерирую изображение…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WAI.textMuted)
                }

                LoadingDotsSquare(time: time, color: WAI.accentBright)
                    .frame(width: 360, height: 240)
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }

    private var generationStatusText: String {
        let lower = status.lowercased()
        if lower.contains("думаю") || lower.contains("think") {
            return "Думаю..."
        } else if lower.contains("генерирую") || lower.contains("создаю") {
            return "Генерирую..."
        } else if lower.contains("обрабатываю") || lower.contains("обрабат") {
            return "Обрабатываю..."
        } else {
            return "Генерирую..."
        }
    }

    private var phase: ToolStatusPhase {
        ToolStatusPhase(status)
    }

}

private struct LoadingDotsSquare: View {
    let time: TimeInterval
    let color: Color

    var body: some View {
        dotsCanvas
            .background(squareBackground)
            .shadow(color: WAI.accentGlow.opacity(0.12), radius: 10)
    }

    private var dotsCanvas: some View {
        Canvas { canvas, size in
            drawDots(canvas: &canvas, size: size)
        }
    }

    private var squareBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(hex: 0x202328))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(WAI.accentBright.opacity(0.42), lineWidth: 1)
            )
    }

    private func drawDots(canvas: inout GraphicsContext, size: CGSize) {
        let columns = 24
        let rows = 16
        let stepX = size.width / CGFloat(columns + 1)
        let stepY = size.height / CGFloat(rows + 1)
        for row in 0..<rows {
            for column in 0..<columns {
                let wave = sin(time * 2.2 + Double(column) * 0.34 - Double(row) * 0.28)
                let cross = cos(time * 1.45 - Double(column + row) * 0.18)
                let intensity = max(0, (wave + cross) * 0.5)
                let driftX = CGFloat(sin(time * 1.1 + Double(row) * 0.3)) * 1.1
                let driftY = CGFloat(cos(time * 1.0 + Double(column) * 0.25)) * 1.0
                let radius = 1.1 + CGFloat(intensity) * 2.6
                let x = CGFloat(column + 1) * stepX + driftX
                let y = CGFloat(row + 1) * stepY + driftY
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                let opacity = 0.12 + CGFloat(intensity) * 0.52
                canvas.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
    }
}

private struct ToolStatusPhase {
    let title: String
    let icon: String
    let color: Color

    init(_ status: String) {
        let lower = status.lowercased()
        if lower.contains("провер") || lower.contains("manual") {
            title = "ручная проверка"
            icon = "hand.raised"
            color = WAI.warning
        } else if lower.contains("чита") || lower.contains("смотр") || lower.contains("просматр") {
            title = "читаю"
            icon = "eyes"
            color = WAI.accentBright
        } else if lower.contains("публи") || lower.contains("telegram") || lower.contains("отправ") {
            title = "публикация"
            icon = "paperplane.fill"
            color = WAI.accentBright
        } else if lower.contains("пиш") || lower.contains("текст") || lower.contains("пост") {
            title = "пишу"
            icon = "pencil.and.outline"
            color = WAI.accentBright
        } else if lower.contains("извлека") || lower.contains("парс") || lower.contains("карточ") {
            title = "извлечение"
            icon = "doc.text.magnifyingglass"
            color = WAI.accentBright
        } else if lower.contains("ищ") || lower.contains("поиск") || lower.contains("источник") {
            title = "поиск"
            icon = "magnifyingglass"
            color = WAI.accentBright
        } else if lower.contains("итог") || lower.contains("ответ") {
            title = "сборка ответа"
            icon = "checklist"
            color = WAI.success
        } else {
            title = "работаю"
            icon = "sparkles"
            color = WAI.accentBright
        }
    }
}

private struct AttachmentDeleteButton: View {
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.11, green: 0.61, blue: 0.94))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.15), radius: 3)
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .scaleEffect(hovered ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.15), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// ── Scroll to bottom button ─────────────────────────────

private func scrollToBottomButton(proxy: ScrollViewProxy, onTap: @escaping (Bool) -> Void) -> some View {
    ScrollToBottomPassthroughButton { reachedBottom in
        if reachedBottom == nil {
            onTap(false)
        } else {
            onTap(reachedBottom == true)
        }
    }
    .frame(width: 44, height: 44)
}

private func scrollNavigationShouldShow(in scrollView: NSScrollView) -> Bool {
    guard let documentView = scrollView.documentView else { return false }
    let visible = scrollView.contentView.bounds
    let document = documentView.bounds
    let documentHeight = max(0, document.height)
    let visibleHeight = max(0, visible.height)
    let canScroll = documentHeight > visibleHeight + 4
    let distanceToBottom = documentView.isFlipped
        ? max(0, document.maxY - visible.maxY)
        : max(0, visible.minY - document.minY)
    let threshold = max(160, visible.height * 0.24)
    return canScroll && distanceToBottom > threshold
}

private struct ScrollActivityObserver: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.view = nsView
        context.coordinator.installMonitor()
    }

    final class Coordinator {
        var onChange: (Bool) -> Void
        weak var view: NSView?
        private var monitor: Any?
        private var lastShouldShow: Bool?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let view = self.view,
                      let window = view.window,
                      window.isKeyWindow else { return event }
                let point = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(point) else { return event }
                DispatchQueue.main.async {
                    guard let scrollView = self.scrollView(containing: event.locationInWindow, in: window.contentView) else {
                        return
                    }
                    let shouldShow = scrollNavigationShouldShow(in: scrollView)
                    guard shouldShow != self.lastShouldShow else { return }
                    self.lastShouldShow = shouldShow
                    self.onChange(shouldShow)
                }
                return event
            }
        }

        private func scrollView(containing pointInWindow: NSPoint, in root: NSView?) -> NSScrollView? {
            guard let root else { return nil }
            if let scroll = root as? NSScrollView {
                let point = scroll.convert(pointInWindow, from: nil)
                if scroll.bounds.contains(point) {
                    return scroll
                }
            }
            for subview in root.subviews.reversed() {
                if let match = scrollView(containing: pointInWindow, in: subview) {
                    return match
                }
            }
            return nil
        }
    }
}

private struct ScrollToBottomPassthroughButton: NSViewRepresentable {
    var action: (Bool?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> ControlView {
        let view = ControlView(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        view.action = { context.coordinator.action($0) }
        return view
    }

    func updateNSView(_ nsView: ControlView, context: Context) {
        context.coordinator.action = action
        nsView.action = { context.coordinator.action($0) }
        nsView.needsDisplay = true
    }

    final class Coordinator {
        var action: (Bool?) -> Void

        init(action: @escaping (Bool?) -> Void) {
            self.action = action
        }
    }

    final class ControlView: NSView {
        var action: (Bool?) -> Void = { _ in }
        private var isHovered = false
        private var isPressed = false
        private var trackingArea: NSTrackingArea?

        private let accent = NSColor(
            calibratedRed: 0x4D / 255,
            green: 0xB8 / 255,
            blue: 1,
            alpha: 1
        )

        override var isFlipped: Bool { true }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let options: NSTrackingArea.Options = [
                .mouseEnteredAndExited,
                .activeInKeyWindow,
                .inVisibleRect
            ]
            let next = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(next)
            trackingArea = next
        }

        override func mouseEntered(with event: NSEvent) {
            isHovered = true
            needsDisplay = true
        }

        override func mouseExited(with event: NSEvent) {
            isHovered = false
            isPressed = false
            needsDisplay = true
        }

        override func mouseDown(with event: NSEvent) {
            isPressed = true
            needsDisplay = true
        }

        override func mouseUp(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            let shouldFire = bounds.contains(point)
            isPressed = false
            needsDisplay = true
            if shouldFire {
                action(scrollDownOneChunk())
            }
        }

        override func scrollWheel(with event: NSEvent) {
            if forwardScrollWheel(event) { return }
            super.scrollWheel(with: event)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let inset: CGFloat = isPressed ? 4.5 : 3
            let circleRect = bounds.insetBy(dx: inset, dy: inset)
            let circle = NSBezierPath(ovalIn: circleRect)
            NSColor.clear.setFill()
            circle.fill()
            accent.withAlphaComponent(isHovered ? 1 : 0.95).setStroke()
            circle.lineWidth = isHovered ? 2.0 : 1.6
            circle.stroke()

            let midX = bounds.midX
            let midY = bounds.midY + 1
            let chevron = NSBezierPath()
            chevron.lineWidth = 2.6
            chevron.lineCapStyle = .round
            chevron.lineJoinStyle = .round
            chevron.move(to: NSPoint(x: midX - 7, y: midY - 3))
            chevron.line(to: NSPoint(x: midX, y: midY + 4))
            chevron.line(to: NSPoint(x: midX + 7, y: midY - 3))
            accent.setStroke()
            chevron.stroke()
        }

        private func forwardScrollWheel(_ event: NSEvent) -> Bool {
            guard let window,
                  let contentView = window.contentView,
                  let target = scrollView(containing: event.locationInWindow, in: contentView)
            else {
                return false
            }
            target.scrollWheel(with: event)
            return true
        }

        private func scrollDownOneChunk() -> Bool? {
            guard let window,
                  let contentView = window.contentView,
                  let scrollView = scrollView(containing: convert(bounds.center, to: nil), in: contentView),
                  let documentView = scrollView.documentView
            else {
                return nil
            }

            let visible = scrollView.contentView.bounds
            let document = documentView.bounds
            let maxOffset = max(0, document.height - visible.height)
            guard maxOffset > 4 else { return true }

            let step = min(max(640, visible.height * 0.96), 880)
            let targetY: CGFloat
            let reachedBottom: Bool
            if documentView.isFlipped {
                targetY = min(maxOffset, visible.origin.y + step)
                reachedBottom = maxOffset - targetY <= 3
            } else {
                targetY = max(document.minY, visible.origin.y - step)
                reachedBottom = targetY <= document.minY + 3
            }

            let target = NSPoint(x: visible.origin.x, y: targetY)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.allowsImplicitAnimation = true
                scrollView.contentView.animator().setBoundsOrigin(target)
            } completionHandler: {
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }

            return reachedBottom
        }

        private func scrollView(containing pointInWindow: NSPoint, in root: NSView) -> NSScrollView? {
            if let scroll = root as? NSScrollView {
                let point = scroll.convert(pointInWindow, from: nil)
                if scroll.bounds.contains(point) {
                    return scroll
                }
            }
            for subview in root.subviews.reversed() {
                if let match = scrollView(containing: pointInWindow, in: subview) {
                    return match
                }
            }
            return nil
        }
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}

private struct ScrollPositionObserver: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ObserverView(frame: .zero)
        view.onMove = { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onChange = onChange
        DispatchQueue.main.async {
            context.coordinator.attach(from: nsView)
            context.coordinator.report()
        }
    }

    final class ObserverView: NSView {
        var onMove: (() -> Void)?

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            DispatchQueue.main.async { [weak self] in self?.onMove?() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.onMove?() }
        }
    }

    final class Coordinator: NSObject {
        var onChange: (Bool) -> Void
        private weak var scrollView: NSScrollView?
        private var observer: NSObjectProtocol?
        private var liveObserver: NSObjectProtocol?
        private var lastShouldShow: Bool?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            if let liveObserver {
                NotificationCenter.default.removeObserver(liveObserver)
            }
        }

        func attach(from view: NSView) {
            guard scrollView == nil else {
                report()
                return
            }
            guard let scroll = findScrollView(from: view) else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak view] in
                    guard let view else { return }
                    self?.attach(from: view)
                }
                return
            }
            scrollView = scroll
            scroll.contentView.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scroll.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.report()
            }
            liveObserver = NotificationCenter.default.addObserver(
                forName: NSScrollView.didLiveScrollNotification,
                object: scroll,
                queue: .main
            ) { [weak self] _ in
                self?.report()
            }
            report(force: true)
        }

        private func findScrollView(from view: NSView) -> NSScrollView? {
            var current: NSView? = view
            while let node = current {
                if let scroll = node as? NSScrollView { return scroll }
                current = node.superview
            }
            return view.enclosingScrollView
        }

        func report(force: Bool = false) {
            guard let scrollView else { return }
            let shouldShow = scrollNavigationShouldShow(in: scrollView)
            guard force || shouldShow != lastShouldShow else { return }
            lastShouldShow = shouldShow
            onChange(shouldShow)
        }
    }
}
