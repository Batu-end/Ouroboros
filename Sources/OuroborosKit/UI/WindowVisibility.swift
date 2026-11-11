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

    /// Internal rather than private so the gate can be tested: a probe that wrongly reports
    /// "hidden" freezes the ring, which is invisible in a unit test but obvious to a user.
    final class ProbeView: NSView {
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
            // `isVisible` alone, deliberately. Occlusion state is updated asynchronously by
            // the window server, so consulting it the instant the popover opens can report
            // "hidden" and leave the ring frozen. Closing the popover orders the window out,
            // which flips `isVisible` immediately — that is the case worth catching.
            onChange?(window.isVisible)
        }
    }
}
