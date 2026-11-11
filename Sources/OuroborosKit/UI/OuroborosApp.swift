import SwiftUI

/// Menu-bar-only app. `LSUIElement` in Info.plist keeps it out of the Dock, so the status
/// item and its popover are the entire interface.
public struct OuroborosApp: App {

    @StateObject private var engine = TimerEngine()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            PopoverView(engine: engine)
        } label: {
            // The status bar flattens its label to one run, so the symbol is interpolated
            // into the Text rather than placed in an HStack beside it.
            Text("\(Image(systemName: engine.menuBarSymbol))\(engine.menuBarText.isEmpty ? "" : "  " + engine.menuBarText)")
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
