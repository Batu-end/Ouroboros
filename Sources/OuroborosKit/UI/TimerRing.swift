import SwiftUI

/// The hero readout. On break the ring depletes toward zero; while working it sweeps
/// once a minute — motion without inventing a deadline that does not exist.
struct TimerRing: View {
    let phase: AppPhase
    let progress: Double
    let primary: String
    let caption: String

    private var accent: Color { Theme.accent(for: phase) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 8)

            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.55), accent], center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)
                .shadow(color: accent.opacity(0.35), radius: 6)

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
