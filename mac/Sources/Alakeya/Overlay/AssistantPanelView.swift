import SwiftUI

// ============================================================
// AssistantPanelView.swift — glass panel, ported from AssistantPanel.jsx.
// ============================================================

private struct QuickAction: Identifiable {
    let id: String; let label: String; let icon: String
}

private let quickActions: [QuickAction] = [
    .init(id: "open", label: "Открыть", icon: "square.grid.2x2"),
    .init(id: "search", label: "Найти", icon: "magnifyingglass"),
    .init(id: "summarize", label: "Резюме", icon: "text.alignleft"),
    .init(id: "write", label: "Написать", icon: "pencil"),
    .init(id: "organize", label: "Файлы", icon: "folder"),
    .init(id: "image", label: "Картинка", icon: "sparkles"),
    .init(id: "translate", label: "Перевести", icon: "character.book.closed"),
    .init(id: "settings", label: "Настройки", icon: "gearshape"),
]

struct AssistantPanelView: View {
    @ObservedObject var store: AgentStore
    var onSubmit: (String) -> Void
    var onVoiceStart: () -> Void
    var onVoiceStop: () -> Void
    var onQuick: (String) -> Void

    @State private var text = ""
    @FocusState private var inputFocused: Bool

    private var isListening: Bool { store.orbState == .listening }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if isListening && !store.transcript.isEmpty { transcriptView }
            if let task = store.task { taskView(task) }
            inputRow
            Text("БЫСТРЫЕ ДЕЙСТВИЯ")
                .font(.system(size: 10, weight: .medium)).tracking(2)
                .foregroundStyle(WAI.textMuted)
            quickGrid
        }
        .padding(24)
        .frame(width: 360)
        .background(glass)
        .clipShape(RoundedRectangle(cornerRadius: WAI.r2xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: WAI.r2xl).stroke(WAI.lineStrong))
        .shadow(color: .black.opacity(0.7), radius: 30, y: 24)
        .onAppear { inputFocused = true }
    }

    private var header: some View {
        HStack(spacing: 14) {
            OrbView(state: store.orbState, size: 52) { store.panelOpen = false }
            VStack(alignment: .leading, spacing: 2) {
                Text("Alakeya").font(.system(size: 15, weight: .semibold)).foregroundStyle(WAI.text)
                HStack(spacing: 6) {
                    Circle().fill(store.orbState == .error ? WAI.warningSoft : WAI.accentBright)
                        .frame(width: 6, height: 6)
                    Text(store.status.rawValue).font(.system(size: 12)).foregroundStyle(WAI.accentBright)
                }
            }
            Spacer()
            iconButton("minus") { store.panelOpen = false }
            iconButton("xmark") { store.panelOpen = false }
        }
    }

    private var transcriptView: some View {
        Text(store.transcript)
            .font(.system(size: 14)).foregroundStyle(WAI.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(WAI.accentSoft)
            .overlay(RoundedRectangle(cornerRadius: WAI.rLg).stroke(WAI.lineAccent))
            .clipShape(RoundedRectangle(cornerRadius: WAI.rLg))
    }

    private func taskView(_ task: CurrentTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title).font(.system(size: 12)).foregroundStyle(WAI.textDim)
            ForEach(task.steps) { step in
                HStack(spacing: 10) {
                    stepDot(step.status)
                    Text(step.label)
                        .font(.system(size: 13, weight: step.status == .active ? .medium : .regular))
                        .foregroundStyle(step.status == .active ? WAI.text : WAI.textMuted)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(RoundedRectangle(cornerRadius: WAI.rLg).stroke(WAI.line))
        .clipShape(RoundedRectangle(cornerRadius: WAI.rLg))
    }

    private func stepDot(_ status: StepStatus) -> some View {
        ZStack {
            Circle().stroke(status == .active ? WAI.accentBright : WAI.lineStrong, lineWidth: 1)
                .background(Circle().fill(status == .done ? WAI.accentSoft : .clear))
                .frame(width: 16, height: 16)
            if status == .done { Image(systemName: "checkmark").font(.system(size: 8)).foregroundStyle(WAI.accentBright) }
        }
        .frame(width: 16, height: 16)
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("Скажи или напиши задачу…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13)).foregroundStyle(WAI.text)
                .focused($inputFocused)
                .onSubmit(submit)
            Button(action: isListening ? onVoiceStop : onVoiceStart) {
                HStack(spacing: 5) { ForEach(0..<3) { _ in Circle().fill(WAI.accentBright).frame(width: 5, height: 5) } }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(WAI.accentSoft)
                    .overlay(Capsule().stroke(WAI.lineAccent))
                    .clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(WAI.surfaceInset)
        .overlay(RoundedRectangle(cornerRadius: WAI.rLg).stroke(WAI.lineStrong))
        .clipShape(RoundedRectangle(cornerRadius: WAI.rLg))
    }

    private var quickGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(quickActions) { a in
                Button { onQuick(a.id) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: a.icon).font(.system(size: 16)).foregroundStyle(WAI.accentBright)
                        Text(a.label).font(.system(size: 9)).foregroundStyle(WAI.textDim)
                    }
                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit).padding(8)
                    .background(WAI.surfaceInset)
                    .overlay(RoundedRectangle(cornerRadius: WAI.rLg).stroke(WAI.line))
                    .clipShape(RoundedRectangle(cornerRadius: WAI.rLg))
                }.buttonStyle(.plain)
            }
        }
    }

    private func iconButton(_ system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 11)).foregroundStyle(WAI.textDim)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.06)).clipShape(Circle())
                .overlay(Circle().stroke(WAI.line))
        }.buttonStyle(.plain)
    }

    private var glass: some View { WAI.surface }

    private func submit() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSubmit(t); text = ""
    }
}
