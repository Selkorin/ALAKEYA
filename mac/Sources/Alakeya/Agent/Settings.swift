import Foundation

// ============================================================
// Settings.swift — user settings, ported from SettingsWindow's
// SETTINGS_DEFAULTS (handoff/src/SettingsWindow.jsx).
// ============================================================

struct Settings: Codable {
    struct Appearance: Codable {
        var size = "medium"          // small | medium | large
        var corner = "bottom-right"
        var theme = "system"
        var glow = 0.68
        var particles = 0.5
        var faceStyle = "friendly"
        var accentHex: UInt32 = 0x06B6D4
    }
    struct Voice: Codable {
        var activation = "push"      // click | wake | push
        var wakeWord = "Hey Alakeya"
        var micDeviceId = "default"
        var ttsEnabled = true
        var speed = 1.0
        var localOnly = false        // privacy mode (DOC2 §"Локальная речь")
    }
    struct Automation: Codable {
        var autoSafe = false         // auto-confirm low-risk
        var neverSend = true
        var neverDelete = true
        var neverPay = true
        var allowedApps = ["Safari", "Chrome", "Notes", "Mail"]
    }
    struct Developer: Codable {
        var model = "gpt-4o-mini"
        var sttModel = "whisper-1"
        var ttsVoice = "alloy"
    }

    var appearance = Appearance()
    var voice = Voice()
    var automation = Automation()
    var developer = Developer()

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: "alakeya.settings"),
              let s = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "alakeya.settings")
        }
    }
}

struct OnboardingResult {
    var accent: UInt32? = nil
    var faceStyle: String? = nil
}
