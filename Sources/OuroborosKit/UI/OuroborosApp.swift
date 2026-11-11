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
            // The status bar renders a single Text; the emoji carries the phase.
            Text(engine.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
