import SwiftUI

enum Theme {
    static let popoverWidth: CGFloat = 300
    static let gutter: CGFloat = 16
    static let corner: CGFloat = 12

    static let work = Color(nsColor: .systemTeal)
    static let rest = Color(nsColor: .systemOrange)

    static func accent(for phase: AppPhase) -> Color {
        switch phase {
        case .idle:    return .secondary
        case .working: return work
        case .onBreak: return rest
        }
    }

    static let phaseChange: Animation = .smooth(duration: 0.35)
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
