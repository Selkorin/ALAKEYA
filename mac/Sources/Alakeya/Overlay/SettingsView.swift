import SwiftUI

// ============================================================
// SettingsView.swift — settings window, ported from SettingsWindow.jsx
// (6+1 tabs). Bindings persist via AgentStore.settings.
// ============================================================

struct SettingsView: View {
    @ObservedObject var store: AgentStore
    var onClose: () -> Void

    @State private var tab = "appearance"

    private let tabs: [(String, String)] = [
        ("appearance", "Внешний вид"), ("voice", "Голос"), ("permissions", "Разрешения"),
        ("automation", "Автоматизация"), ("memory", "Память"), ("developer", "Разработчик"),
        ("about", "О программе"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(WAI.line)
            ScrollView { content.padding(28) }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 720, height: 520)
        .background(WAI.surfaceStrong)
        .overlay(RoundedRectangle(cornerRadius: WAI.r2xl).stroke(WAI.lineStrong))
        .clipShape(RoundedRectangle(cornerRadius: WAI.r2xl))
        .shadow(color: .black.opacity(0.7), radius: 30, y: 24)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Настройки").font(.system(size: 17, weight: .semibold)).foregroundStyle(WAI.text)
                Spacer()
                Button { onClose() } label: { Image(systemName: "xmark").foregroundStyle(WAI.textDim) }.buttonStyle(.plain)
            }.padding(.bottom, 12)
            ForEach(tabs, id: \.0) { t in
                Button { tab = t.0 } label: {
                    Text(t.1).font(.system(size: 13))
                        .foregroundStyle(tab == t.0 ? WAI.text : WAI.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(tab == t.0 ? WAI.accentSoft : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: WAI.rMd))
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(18).frame(width: 200, alignment: .topLeading)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case "appearance": appearance
        case "voice": voice
        case "permissions": permissions
        case "automation": automation
        case "memory": memory
        case "developer": developer
        default: about
        }
    }

    // ── sections ──────────────────────────────────────────
    private var appearance: some View {
        section("Внешний вид") {
            row("Акцент") {
                HStack(spacing: 8) {
                    ForEach([UInt32(0x3B82F6), 0x06B6D4, 0x8B5CF6, 0xEC4899, 0x4ADE80], id: \.self) { c in
                        Circle().fill(Color(hex: c)).frame(width: 26, height: 26)
                            .overlay(Circle().stroke(.white, lineWidth: store.settings.appearance.accentHex == c ? 2 : 0))
                            .onTapGesture {
                                store.settings.appearance.accentHex = c
                                WAI.accent = Color(hex: c); store.settings.save()
                            }
                    }
                }
            }
            row("Размер орба") { picker(["small", "medium", "large"], $store.settings.appearance.size) }
            row("Тема") { picker(["system", "dark", "light"], $store.settings.appearance.theme) }
        }
    }

    private var voice: some View {
        section("Голос") {
            row("Активация") { picker(["click", "wake", "push"], $store.settings.voice.activation) }
            toggleRow("Озвучивать ответы (TTS)", $store.settings.voice.ttsEnabled)
            toggleRow("Локальная речь (privacy)", $store.settings.voice.localOnly)
        }
    }

    private var permissions: some View {
        section("Разрешения") {
            permRow("Accessibility", PermissionsManager.shared.accessibilityGranted) { PermissionsManager.shared.requestAccessibility() }
            permRow("Screen Recording", PermissionsManager.shared.screenRecordingGranted) { _ = PermissionsManager.shared.requestScreenRecording() }
            permRow("Микрофон", PermissionsManager.shared.microphoneGranted) { Task { _ = await PermissionsManager.shared.requestMicrophone() } }
        }
    }

    private var automation: some View {
        section("Автоматизация") {
            toggleRow("Авто-подтверждать безопасные действия", Binding(
                get: { store.settings.automation.autoSafe },
                set: { store.settings.automation.autoSafe = $0
                       PolicyEngine.shared.mode = $0 ? .auto : .manual
                       store.settings.save() }))
            Text("Жёсткие лимиты (всегда спрашивать): отправка писем, удаление, платежи.")
                .font(.system(size: 12)).foregroundStyle(WAI.textMuted)
        }
    }

    private var memory: some View {
        section("Память") {
            Button("Очистить журнал и правила") {
                store.activity = []; Store.shared.saveActivity([])
            }.buttonStyle(.plain).foregroundStyle(WAI.danger)
        }
    }

    private var developer: some View {
        section("Разработчик") {
            row("Модель") { Text(store.settings.developer.model).foregroundStyle(WAI.textDim) }
            Text("OPENAI_API_KEY читается из окружения. Без ключа работает офлайн-планировщик.")
                .font(.system(size: 12)).foregroundStyle(WAI.textMuted)
        }
    }

    private var about: some View {
        section("О программе") {
            Text("Alakeya · v0.1 · 2026").foregroundStyle(WAI.text)
            Text("Нативный macOS-ассистент. Electron-референс — в /desktop.")
                .font(.system(size: 12)).foregroundStyle(WAI.textMuted)
        }
    }

    // ── helpers ───────────────────────────────────────────
    private func section(_ title: String, @ViewBuilder _ body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 22, weight: .semibold)).foregroundStyle(WAI.text)
            body()
        }
    }
    private func row(_ label: String, @ViewBuilder _ control: () -> some View) -> some View {
        HStack { Text(label).font(.system(size: 13)).foregroundStyle(WAI.textDim); Spacer(); control() }
    }
    private func toggleRow(_ label: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) { Text(label).font(.system(size: 13)).foregroundStyle(WAI.textDim) }
            .toggleStyle(.switch).tint(WAI.accent)
            .onChange(of: binding.wrappedValue) { _, _ in store.settings.save() }
    }
    private func picker(_ options: [String], _ binding: Binding<String>) -> some View {
        Picker("", selection: binding) { ForEach(options, id: \.self) { Text($0).tag($0) } }
            .pickerStyle(.segmented).frame(width: 240)
            .onChange(of: binding.wrappedValue) { _, _ in store.settings.save() }
    }
    private func permRow(_ label: String, _ granted: Bool, _ request: @escaping () -> Void) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(WAI.textDim)
            Spacer()
            if granted { Text("Выдано").foregroundStyle(WAI.success).font(.system(size: 12)) }
            else { Button("Выдать", action: request).buttonStyle(.plain).foregroundStyle(WAI.accentBright).font(.system(size: 12)) }
        }
    }
}
