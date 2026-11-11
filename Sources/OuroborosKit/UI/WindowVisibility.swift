import AppKit
import SwiftUI

/// Reports whether the view's window is actually on screen.
///
/// `MenuBarExtra` keeps its content alive after the popover closes, so an animating
/// `TimelineView` inside it would keep redrawing at display rate against a window nobody can
/// see — around half a core, forever. This is the signal that stops that.
struct WindowVisibility: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> NSView {
        let view = ProbeView()
        view.onChange = { visible in
            Task { @MainActor in
                if isVisible != visible { isVisible = visible }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ProbeView)?.report()
    }

    private final class ProbeView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observers: [any NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()

            if let window {
                for name: Notification.Name in [NSWindow.didChangeOcclusionStateNotification,
                                                NSWindow.didMiniaturizeNotification,
                                                NSWindow.didDeminiaturizeNotification,
                                                NSWindow.willCloseNotification] {
                    observers.append(NotificationCenter.default.addObserver(
                        forName: name, object: window, queue: .main
                    ) { [weak self] _ in
                        MainActor.assumeIsolated { self?.report() }
                    })
                }
            }
            report()
        }

        func report() {
            guard let window else {
                onChange?(false)
                return
            }
            // A key window is on screen by definition; the occlusion check is only there to
            // pause when the panel is fully covered, and must never freeze a visible ring.
            let visible = window.isVisible
                && (window.isKeyWindow || window.occlusionState.contains(.visible))
            onChange?(visible)
        }
    }
}
