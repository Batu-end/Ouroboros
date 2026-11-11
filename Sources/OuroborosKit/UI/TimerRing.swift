import SwiftUI

/// The hero readout. On break the ring depletes across the whole break; while working it
/// sweeps once a minute — motion without inventing a deadline that does not exist.
///
/// The arc samples `progress(at:)` inside a `TimelineView(.animation)`, so it advances at a
/// constant speed rather than stepping once a second. Only the arc is inside the timeline;
/// the digits are redrawn once a second by the engine, as they should be.
struct TimerRing: View {
    let phase: AppPhase
    let progress: (Date) -> Double
    let primary: String
    let caption: String
    /// Whole 10-minute work blocks completed; a change fires the pulse.
    let milestone: Int

    /// 1 at the instant of a milestone, animated down to 0 — which is also its resting value,
    /// so the flash ring is fully invisible unless it is actually firing.
    @State private var pulse: Double = 0
    @State private var onScreen = false

    private var accent: Color { Theme.accent(for: phase) }

    /// `1:15:42` needs more room than `14:25`, so the readout steps down a size rather than
    /// letting the digits reflow and jitter.
    private var readoutSize: CGFloat { primary.count >= 7 ? 28 : 34 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 8)

            // 30fps is indistinguishable from display rate for a sweeping ring and a
            // fraction of the cost; paused outright whenever the popover is not on screen.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !onScreen || phase.isIdle)) { context in
                RingArc(progress: progress(context.date), accent: accent)
            }

            MilestoneFlash(pulse: pulse, accent: accent)

            RingReadout(primary: primary, caption: caption, size: readoutSize)
        }
        .frame(width: 148, height: 148)
        .background(WindowVisibility(isVisible: $onScreen))
        .animation(.easeOut(duration: 0.25), value: readoutSize)
        .onChange(of: milestone) { _, new in
            guard new > 0 else { return }   // only real 10-minute marks, not resets
            pulse = 1
            withAnimation(.easeOut(duration: 0.9)) { pulse = 0 }
        }
    }
}

/// The swept arc itself, split out from `TimerRing` so it can be rendered — and therefore
/// tested — without the `TimelineView` that drives it (`ImageRenderer` cannot draw one).
struct RingArc: View {
    let progress: Double
    let accent: Color

    /// Exactly zero draws nothing. A blanket floor above zero would leave a lone round cap
    /// parked at 12 o'clock through the whole idle and waiting phases, while a sliver of
    /// real progress still needs to be visible.
    static func trimEnd(for progress: Double) -> Double {
        guard progress > 0 else { return 0 }
        return min(1, max(progress, 0.004))
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: Self.trimEnd(for: progress))
            // The gradient starts and ends on the same colour. An angular gradient that
            // ramps from faded to solid leaves a seam where it wraps, and paints the arc's
            // leading round cap in the faded shade — which read as a pale blob stuck to the
            // top of the ring. The dip now sits mid-arc, away from both caps.
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [accent, accent.opacity(0.68), accent]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: accent.opacity(0.35), radius: 6)
    }
}

/// The 10-minute flash: a full ring that blooms outward and fades.
///
/// `pulse` is 1 at the instant of a milestone and 0 the rest of the time. Resting at zero
/// opacity is the whole contract: an earlier version rested at 0.85 and quietly covered the
/// progress arc with a full ring.
struct MilestoneFlash: View {
    let pulse: Double
    let accent: Color

    var body: some View {
        Circle()
            .stroke(accent, lineWidth: 8)
            .scaleEffect(1 + 0.14 * (1 - pulse))
            .opacity(0.85 * pulse)
            .allowsHitTesting(false)
    }
}

/// The digits and their one-line caption, split out so the layout can be rendered and
/// measured: a caption that spills outside the ring is a visual bug a logic test cannot see.
struct RingReadout: View {
    let primary: String
    let caption: String
    let size: CGFloat

    /// The widest a line can be and still sit inside a 148pt ring drawn with an 8pt stroke.
    static let innerWidth: CGFloat = 104

    var body: some View {
        VStack(spacing: 2) {
            Text(primary)
                .font(.system(size: size, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
                .frame(width: 126)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(width: Self.innerWidth)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.blurReplace)
        }
    }
}
