import Foundation
import CoreGraphics

// ============================================================
// ScreenReader.swift — CoreGraphics grounding for visual verification / VLM fallback.
// Requires the Screen Recording TCC permission.
// ============================================================

@available(macOS 14.0, *)
final class ScreenReader {

    /// Capture the main display as a CGImage for verification or a VLM pass.
    func captureMainDisplay() async throws -> CGImage {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw NSError(domain: "Alakeya.ScreenReader", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось сделать снимок основного дисплея. Если доступ уже включён, выключите и снова включите Alakeya в Запись экрана, затем перезапустите приложение."])
        }
        return image
    }

    /// Lightweight description hook — point a VLM here in production.
    func describeScreen() async -> String {
        if (try? await captureMainDisplay()) != nil {
            return "Снимок экрана получен (грундинг доступен)."
        }
        return "Снимок недоступен — проверь разрешение Screen Recording."
    }
}
