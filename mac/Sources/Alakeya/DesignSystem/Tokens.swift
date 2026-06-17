import SwiftUI

// ============================================================
// Tokens.swift — design tokens ported from the ALAKEYA design
// system (handoff/src/tokens.css). Single source of truth for
// colors, radii, durations and the orb gradients.
// ============================================================

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum WAI {
    // ── Color · base ──────────────────────────────────────
    static let bg            = Color(hex: 0x07070D)
    static let surface       = Color(hex: 0x0A0A14, alpha: 0.65)
    static let surfaceStrong = Color(hex: 0x0A0A14, alpha: 0.78)
    static let surfaceInset  = Color.white.opacity(0.04)

    // ── Borders ───────────────────────────────────────────
    static let line          = Color.white.opacity(0.08)
    static let lineStrong    = Color.white.opacity(0.14)
    static let lineAccent    = Color(hex: 0x06B6D4, alpha: 0.35)

    // ── Text ──────────────────────────────────────────────
    static let text      = Color.white.opacity(0.92)
    static let textDim   = Color.white.opacity(0.65)
    static let textMuted = Color.white.opacity(0.45)
    static let textFaint = Color.white.opacity(0.30)

    // ── Accent (cyan plasma) ──────────────────────────────
    static var accent      = Color(hex: 0x06B6D4) // overridable from settings
    static let accentBright = Color(hex: 0x67E8F9)
    static let accentPale   = Color(hex: 0xA8F2FF)
    static let accentDeep   = Color(hex: 0x0891B2)
    static let accentSoft   = Color(hex: 0x06B6D4, alpha: 0.10)
    static let accentGlow   = Color(hex: 0x06B6D4, alpha: 0.55)

    // ── Semantic ──────────────────────────────────────────
    static let success     = Color(hex: 0x4ADE80)
    static let warning      = Color(hex: 0xFBBF24)
    static let warningSoft = Color(hex: 0xF59E0B)
    static let danger      = Color(hex: 0xF87171)

    // ── Radii ─────────────────────────────────────────────
    static let rSm: CGFloat = 6
    static let rMd: CGFloat = 10
    static let rLg: CGFloat = 14
    static let rXl: CGFloat = 22
    static let r2xl: CGFloat = 28
    static let rPill: CGFloat = 999

    // ── Durations (seconds) ───────────────────────────────
    static let durInstant = 0.12
    static let durFast    = 0.20
    static let durMorph   = 0.24
    static let durMedium  = 0.40
    static let durBreath  = 4.0

    static let easeOut = Animation.timingCurve(0.16, 1, 0.3, 1)

    // ── Typography ────────────────────────────────────────
    static let mono = Font.system(.body, design: .monospaced)

    // ── Orb gradients ─────────────────────────────────────
    static let orbCore = RadialGradient(
        colors: [Color(hex: 0xC8F5FF), Color(hex: 0x06B6D4), Color(hex: 0x1E1B4B), Color(hex: 0x050216)],
        center: UnitPoint(x: 0.35, y: 0.30), startRadius: 0, endRadius: 60
    )
    static let orbCoreError = RadialGradient(
        colors: [Color(hex: 0xFEE6B0), Color(hex: 0xF59E0B), Color(hex: 0x4B1C03), Color(hex: 0x1A0700)],
        center: UnitPoint(x: 0.35, y: 0.30), startRadius: 0, endRadius: 60
    )
}
