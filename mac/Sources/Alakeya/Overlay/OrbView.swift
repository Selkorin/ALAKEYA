import SwiftUI

// ============================================================
// OrbView.swift — the floating sphere with 7 states, ported from
// Orb.jsx / Orb.module.css / animations.css.
// ============================================================

struct OrbView: View {
    let state: OrbState
    var size: CGFloat = 72
    var onTap: (() -> Void)?

    @State private var breathe = false

    private var isError: Bool { state == .error }

    var body: some View {
        ZStack {
            halo
            if state == .listening { pulseRings }
            if state == .thinking { orbitals }
            sphere
            if state == .idle { sparks }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture { onTap?() }
        .onAppear { breathe = true }
    }

    // ── halo ──────────────────────────────────────────────
    private var halo: some View {
        Circle()
            .fill(RadialGradient(
                colors: [isError ? WAI.warningSoft.opacity(0.4) : WAI.accentGlow, .clear],
                center: .center, startRadius: 0, endRadius: size * 0.7))
            .scaleEffect(breathe ? 1.12 : 1.0)
            .opacity(breathe ? 0.9 : 0.55)
            .padding(-size * 0.2)
            .animation(.easeInOut(duration: WAI.durBreath).repeatForever(autoreverses: true), value: breathe)
    }

    // ── sphere + face ─────────────────────────────────────
    private var sphere: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: state != .thinking && state != .acting)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Circle()
                .fill(isError ? WAI.orbCoreError : WAI.orbCore)
                .overlay(face)
                .shadow(color: shadowColor, radius: shadowRadius)
                .scaleEffect(scalePulse)
                .rotationEffect(.degrees(state == .thinking ? (t * 45).truncatingRemainder(dividingBy: 360) : 0))
                .animation(breathAnim, value: breathe)
        }
    }

    private var face: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                eye.position(x: w * 0.32, y: w * 0.37)
                eye.position(x: w * 0.68, y: w * 0.37)
                mouth(width: w)
            }
        }
    }

    private var eye: some View {
        Circle().fill(.white).frame(width: size * 0.08, height: size * 0.08)
    }

    @ViewBuilder
    private func mouth(width w: CGFloat) -> some View {
        switch state {
        case .listening:
            VoiceDots().frame(width: w * 0.3, height: w * 0.18)
                .position(x: w / 2, y: w * 0.74)
        case .thinking, .acting:
            Rectangle().fill(.white).frame(width: w * 0.4, height: 2)
                .position(x: w / 2, y: w * 0.7)
        case .speaking:
            SpeakingMouth().frame(width: w * 0.22, height: w * 0.22)
                .position(x: w / 2, y: w * 0.7)
        case .error:
            Arc(frown: true).stroke(.white, lineWidth: 2).frame(width: w * 0.4, height: w * 0.14)
                .position(x: w / 2, y: w * 0.74)
        default:
            Arc(frown: false).stroke(.white, lineWidth: 2).frame(width: w * 0.4, height: w * 0.14)
                .opacity(0.9).position(x: w / 2, y: w * 0.72)
        }
    }

    // ── listening rings ───────────────────────────────────
    private var pulseRings: some View {
        ZStack {
            ForEach(0..<3) { i in RingView(delay: Double(i) * 0.6) }
        }
    }

    // ── thinking orbitals ─────────────────────────────────
    private var orbitals: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                particle.offset(y: -size * 0.64).rotationEffect(.degrees((t * 90).truncatingRemainder(dividingBy: 360)))
                particle.offset(y: size * 0.64).rotationEffect(.degrees((t * 90).truncatingRemainder(dividingBy: 360)))
                particle.scaleEffect(0.7).offset(x: size * 0.5)
                    .rotationEffect(.degrees(-(t * 60).truncatingRemainder(dividingBy: 360)))
            }
        }
    }

    private var particle: some View {
        Circle().fill(WAI.accentBright).frame(width: 4, height: 4)
            .shadow(color: WAI.accent, radius: 4)
    }

    // ── idle sparks ───────────────────────────────────────
    private var sparks: some View {
        ZStack {
            Spark(delay: 0).offset(x: -size * 0.2, y: -size * 0.45)
            Spark(delay: 0.6).offset(x: size * 0.46, y: size * 0.4)
            Spark(delay: 1.2).offset(x: size * 0.5, y: -size * 0.3)
        }
    }

    // ── derived visual params ─────────────────────────────
    private var shadowColor: Color {
        switch state {
        case .listening, .acting: return WAI.accent.opacity(0.85)
        case .permission: return WAI.warning.opacity(0.55)
        case .error: return WAI.warningSoft.opacity(0.7)
        default: return WAI.accentGlow
        }
    }
    private var shadowRadius: CGFloat {
        (state == .listening || state == .acting || state == .error) ? size * 0.4 : size * 0.28
    }
    private var scalePulse: CGFloat {
        switch state {
        case .idle, .listening: return breathe ? 1.04 : 1.0
        case .speaking: return breathe ? 1.06 : 0.97
        default: return 1.0
        }
    }
    private var breathAnim: Animation {
        switch state {
        case .speaking: return .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        case .listening: return .easeInOut(duration: 2).repeatForever(autoreverses: true)
        default: return .easeInOut(duration: WAI.durBreath).repeatForever(autoreverses: true)
        }
    }
}

// ── small animated subviews ──────────────────────────────
private struct VoiceDots: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Capsule().fill(.white).frame(width: 3)
                    .scaleEffect(y: on ? 1.6 : 0.5, anchor: .center)
                    .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15), value: on)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onAppear { on = true }
    }
}

private struct SpeakingMouth: View {
    @State private var on = false
    var body: some View {
        Circle().stroke(.white, lineWidth: 2)
            .scaleEffect(y: on ? 1.4 : 0.8)
            .animation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

private struct RingView: View {
    let delay: Double
    @State private var on = false
    var body: some View {
        Circle().stroke(WAI.accentBright, lineWidth: 1.5)
            .scaleEffect(on ? 1.7 : 0.6)
            .opacity(on ? 0 : 0.8)
            .animation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(delay), value: on)
            .onAppear { on = true }
    }
}

private struct Spark: View {
    let delay: Double
    @State private var on = false
    var body: some View {
        Circle().fill(WAI.accentPale).frame(width: 3, height: 3)
            .opacity(on ? 0 : 1)
            .scaleEffect(on ? 0.4 : 1)
            .animation(.easeOut(duration: 3).repeatForever(autoreverses: false).delay(delay), value: on)
            .onAppear { on = true }
    }
}

private struct Arc: Shape {
    var frown: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if frown {
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                           control: CGPoint(x: rect.midX, y: rect.minY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                           control: CGPoint(x: rect.midX, y: rect.maxY))
        }
        return p
    }
}
