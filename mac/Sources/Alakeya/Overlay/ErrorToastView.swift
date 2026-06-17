import SwiftUI

// ============================================================
// ErrorToastView.swift — soft amber/red toast, ported from ErrorToast.jsx.
// ============================================================

struct ErrorToastView: View {
    let message: String
    let blocked: Bool
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void

    private var accent: Color { blocked ? WAI.warning : WAI.danger }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(blocked ? "ДЕЙСТВИЕ ЗАБЛОКИРОВАНО" : "ОШИБКА")
                .font(.system(size: 11, weight: .medium)).tracking(2).foregroundStyle(accent)
            Text(message).font(.system(size: 14)).foregroundStyle(WAI.text).lineSpacing(2)
            HStack(spacing: 6) {
                Button("Закрыть", action: onDismiss)
                    .buttonStyle(.plain).foregroundStyle(WAI.textDim).font(.system(size: 13))
                if blocked {
                    Button("Открыть настройки", action: onOpenSettings)
                        .buttonStyle(.plain).foregroundStyle(WAI.text).font(.system(size: 13))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(width: 280, alignment: .leading)
        .background(Color(hex: 0x140C04, alpha: 0.85))
        .overlay(RoundedRectangle(cornerRadius: WAI.rLg).stroke(accent))
        .clipShape(RoundedRectangle(cornerRadius: WAI.rLg))
        .shadow(color: .black.opacity(0.5), radius: 12)
        .task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            onDismiss()
        }
    }
}
