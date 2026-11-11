import AppKit
import SwiftUI

/// A small panel that appears under the menu bar when a break runs out.
///
/// The popover itself cannot be opened programmatically, and a banner is easy to miss — the
/// gap between "break over" and "back at it" is exactly where a 30-minute drift starts. This
/// puts the hand-off in front of the user without stealing focus from whatever is open: it
/// is a non-activating panel, so typing continues to go wherever it was going.
@MainActor
enum BreakOverHUD {

    private static var panel: NSPanel?
    private static var dismissTask: Task<Void, Never>?

    static func show(workSeconds: TimeInterval, breakSeconds: TimeInterval, onResume: @escaping () -> Void) {
        dismiss()

        let content = HUDContent(
            worked: workSeconds,
            rested: breakSeconds,
            onResume: {
                onResume()
                dismiss()
            },
            onDismiss: { dismiss() }
        )

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 290, height: 96)

        let window = NSPanel(contentRect: hosting.frame,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered,
                             defer: false)
        window.contentView = hosting
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = true

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: frame.maxX - hosting.frame.width - 18,
                                          y: frame.maxY - hosting.frame.height - 10))
        }

        window.orderFrontRegardless()
        panel = window

        // Long enough to notice, short enough not to become furniture.
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    static func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct HUDContent: View {
    let worked: TimeInterval
    let rested: TimeInterval
    let onResume: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "infinity.circle.fill")
                    .foregroundStyle(Theme.work)
                Text("Break's over")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            Text("\(BreakMath.humane(rested)) of rest from \(BreakMath.humane(worked)) of work. Loop closed.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryActionButton(title: "Back to Work", systemImage: "play.fill", tint: Theme.work, action: onResume)
        }
        .padding(12)
        .frame(width: 290, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}
