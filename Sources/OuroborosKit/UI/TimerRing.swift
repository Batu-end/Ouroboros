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

    private var accent: Color { Theme.accent(for: phase) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 8)

            TimelineView(.animation(paused: phase.isIdle)) { context in
                Circle()
                    .trim(from: 0, to: max(0.0001, progress(context.date)))
                    .stroke(
                        AngularGradient(colors: [accent.opacity(0.55), accent], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.35), radius: 6)
            }

            VStack(spacing: 2) {
                Text(primary)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.blurReplace)
            }
        }
        .frame(width: 148, height: 148)
    }
}
