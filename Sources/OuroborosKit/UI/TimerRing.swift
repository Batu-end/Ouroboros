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

    @State private var pulse = false
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
                Circle()
                    .trim(from: 0, to: max(0.0001, progress(context.date)))
                    .stroke(
                        AngularGradient(colors: [accent.opacity(0.55), accent], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.35), radius: 6)
            }

            // The milestone flash: a full ring that blooms outward and fades.
            Circle()
                .stroke(accent, lineWidth: 8)
                .scaleEffect(pulse ? 1.14 : 1.0)
                .opacity(pulse ? 0 : 0.85)
                .allowsHitTesting(false)

            VStack(spacing: 2) {
                Text(primary)
                    .font(.system(size: readoutSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText())
                    .frame(width: 126)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .transition(.blurReplace)
            }
        }
        .frame(width: 148, height: 148)
        .background(WindowVisibility(isVisible: $onScreen))
        .animation(.easeOut(duration: 0.25), value: readoutSize)
        .onChange(of: milestone) { _, new in
            guard new > 0 else { return }   // only real 10-minute marks, not resets
            pulse = false
            withAnimation(.easeOut(duration: 0.9)) { pulse = true }
            Task {
                try? await Task.sleep(for: .milliseconds(950))
                pulse = false
            }
        }
    }
}
