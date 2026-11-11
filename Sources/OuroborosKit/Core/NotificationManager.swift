import AppKit
import Foundation
import UserNotifications

/// Best-effort break-over alert. Unsigned / ad-hoc builds can be denied notification
/// authorization, so the banner is never load-bearing: the sound always plays, and the
/// caller can additionally flash the menu bar title.
@MainActor
public final class NotificationManager {

    public private(set) var bannersAvailable = false
    private var didRequest = false

    /// `UNUserNotificationCenter` hard-traps when the process is not an `.app` bundle
    /// (a bare binary, or the test runner), so every call into it is gated on this.
    private var runningInsideAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    public init() {}

    /// Ask once, early, so the first break does not stall on a permission prompt.
    public func prepare() {
        guard !didRequest, runningInsideAppBundle else { return }
        didRequest = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.bannersAvailable = granted }
        }
    }

    /// Fired when a break countdown reaches zero: a soft warm chime, plus a time-sensitive
    /// banner so it still surfaces while Focus is on. Nothing plays when a break *starts* —
    /// stopping work should feel like relief, not an event that announces itself.
    public func breakFinished(workSeconds: TimeInterval, breakSeconds: TimeInterval) {
        play("Purr")
        guard bannersAvailable, runningInsideAppBundle else { return }

        let content = UNMutableNotificationContent()
        content.title = "Break's over"
        content.body = "\(BreakMath.humane(breakSeconds)) of break from \(BreakMath.humane(workSeconds)) of work. Loop closed — pick the next thing."
        content.sound = nil  // the chime above already played; avoid a double hit
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Falls back through a couple of stock sounds, since a missing one returns nil rather
    /// than throwing — silence would make the end of a break easy to miss.
    private func play(_ name: String) {
        let sound = NSSound(named: name) ?? NSSound(named: "Submarine") ?? NSSound(named: "Glass")
        sound?.play()
    }
}
