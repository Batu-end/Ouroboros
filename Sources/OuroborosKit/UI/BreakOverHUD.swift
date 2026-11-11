import AppKit
import SwiftUI

/// A small panel that appears under the menu bar when a break runs out, and stays until it
/// is answered.
///
/// The popover cannot be opened programmatically and a banner is easy to miss, so this is
/// the hand-off: the next work block starts when its button is clicked, and not before. It
/// does not steal focus — a non-activating panel, so typing keeps going where it was going —
/// and it does not time out, because a panel that quietly vanishes is the drift it exists to
/// prevent.
@MainActor
enum BreakOverHUD {

    private static var panel: NSPanel?

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
        hosting.frame = NSRect(x: 0, y: 0, width: 290, height: 112)

        let window = NSPanel(contentRect: hosting.frame,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered,
                             defer: false)
        window.contentView = hosting
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // Above full-screen apps too: this is the only cue that the clock is waiting, and
        // a panel nobody can see is the drift it exists to prevent.
        window.level = .statusBar
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
    }

    static func dismiss() {
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

            Text("\(BreakMath.humane(rested)) of rest from \(BreakMath.humane(worked)) of work. The clock is paused until you start the next block.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryActionButton(title: "Start Next Block", systemImage: "play.fill", tint: Theme.work, action: onResume)
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
