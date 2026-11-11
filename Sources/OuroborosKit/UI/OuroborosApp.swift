import SwiftUI

/// Menu-bar-only app. `LSUIElement` in Info.plist keeps it out of the Dock, so the status
/// item and its popover are the entire interface.
public struct OuroborosApp: App {

    @StateObject private var engine: TimerEngine

    public init() {
        let engine = TimerEngine()
        engine.onBreakCompleted = { [weak engine] completion in
            BreakOverHUD.show(workSeconds: completion.workSeconds,
                              breakSeconds: completion.breakSeconds) {
                // Work resumed the instant the break ended; the button acknowledges that,
                // it does not start a second timer.
                engine?.ensureWorking()
            }
        }
        _engine = StateObject(wrappedValue: engine)
    }

    public var body: some Scene {
        MenuBarExtra {
            PopoverView(engine: engine)
        } label: {
            Image(nsImage: StatusItemImage.make(symbol: engine.menuBarSymbol,
                                                text: engine.menuBarText))
        }
        .menuBarExtraStyle(.window)
    }
}
