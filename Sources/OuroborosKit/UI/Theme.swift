import SwiftUI

enum Theme {
    static let popoverWidth: CGFloat = 300
    static let gutter: CGFloat = 16
    static let corner: CGFloat = 12

    /// Cool and alert for work; warm and soft for recovery. The colour shift is the point:
    /// it marks the boundary between hustle and rest before any text is read.
    static let work = Color(red: 0.23, green: 0.72, blue: 0.72)
    static let rest = Color(red: 0.89, green: 0.62, blue: 0.29)

    static func accent(for phase: AppPhase) -> Color {
        switch phase {
        case .idle:    return .secondary
        case .working: return work
        case .onBreak: return rest
        case .waiting: return work
        }
    }

    /// A faint wash of the phase colour behind the whole popover, so the mode registers
    /// peripherally rather than only in the ring.
    static func wash(for phase: AppPhase) -> LinearGradient {
        let tint = accent(for: phase)
        return LinearGradient(
            colors: [tint.opacity(phase.isIdle ? 0 : 0.14), tint.opacity(0)],
            startPoint: .top,
            endPoint: .center
        )
    }

    static let phaseChange: Animation = .smooth(duration: 0.45)
}

/// Soft inset card used for the log and the stat strip.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
