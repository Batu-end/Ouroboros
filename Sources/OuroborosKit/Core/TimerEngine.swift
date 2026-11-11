import Combine
import Foundation

/// Owns the phase machine, the clock, and the session log. The only mutable source of truth.
@MainActor
public final class TimerEngine: ObservableObject {

    @Published public private(set) var phase: AppPhase = .idle
    @Published public private(set) var sessions: [Session] = []

    /// Bumped once per displayed second; every elapsed/remaining value is derived from it.
    @Published public private(set) var now: Date = .now

    /// Set briefly when a break ends, so the menu bar can announce it even without banners.
    @Published public private(set) var flashUntil: Date?

    /// `1` normally. `OUROBOROS_FAST=1` makes one real second count as a minute, which
    /// makes the full work → break → work loop exercisable in seconds.
    public let timeScale: Double

    private let store: SessionStore
    private let notifier: NotificationManager
    private var ticker: AnyCancellable?
    private var lastDisplayedSecond = -1

    public init(
        store: SessionStore = SessionStore(),
        notifier: NotificationManager = NotificationManager(),
        timeScale: Double? = nil
    ) {
        self.store = store
        self.notifier = notifier
        self.timeScale = timeScale ?? (ProcessInfo.processInfo.environment["OUROBOROS_FAST"] == "1" ? 60 : 1)
        self.sessions = store.load()

        notifier.prepare()
        ticker = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
    }

    // MARK: - Derived time

    /// Seconds worked in the current work block (counts up, open-ended).
    public var workElapsed: TimeInterval {
        guard case .working(let since) = phase else { return 0 }
        return max(0, now.timeIntervalSince(since) * timeScale)
    }

    /// Seconds already spent in the current break.
    public var breakElapsed: TimeInterval {
        guard case .onBreak(let start, _, _) = phase else { return 0 }
        return max(0, now.timeIntervalSince(start) * timeScale)
    }

    /// Seconds left in the current break (counts down).
    public var breakRemaining: TimeInterval {
        guard case .onBreak(_, let duration, _) = phase else { return 0 }
        return max(0, duration - breakElapsed)
    }

    /// Full length of the current break.
    public var breakDuration: TimeInterval {
        if case .onBreak(_, let duration, _) = phase { return duration }
        return 0
    }

    /// Work that paid for the current break.
    public var breakSourceWork: TimeInterval {
        if case .onBreak(_, _, let worked) = phase { return worked }
        return 0
    }

    /// Break time the current work block has banked so far.
    public var bankedBreak: TimeInterval {
        phase.isWorking ? BreakMath.earnedBreak(forWork: workElapsed) : 0
    }

    /// `0...1` for the break ring (depleting) or the work ring (one sweep per minute).
    public var ringProgress: Double {
        switch phase {
        case .idle:
            return 0
        case .working:
            return (workElapsed.truncatingRemainder(dividingBy: 60)) / 60
        case .onBreak:
            guard breakDuration > 0 else { return 0 }
            return breakRemaining / breakDuration
        }
    }

    public var isFlashing: Bool {
        guard let flashUntil else { return false }
        return now < flashUntil
    }

    /// What the status bar shows, by phase.
    public var menuBarTitle: String {
        if isFlashing { return "✅ back to it" }
        switch phase {
        case .idle:      return "⟳"
        case .working:   return "💼 \(BreakMath.clock(workElapsed))"
        case .onBreak:   return "☕ \(BreakMath.clock(breakRemaining))"
        }
    }

    // MARK: - Transitions

    public func startWork() {
        flashUntil = nil
        phase = .working(since: .now)
        resetTickCache()
    }

    /// "I'm Distracted / Take Break" — bank 18% of what was actually worked.
    public func takeBreak() {
        guard case .working = phase else { return }
        let worked = workElapsed
        let earned = BreakMath.earnedBreak(forWork: worked)
        phase = .onBreak(start: .now, duration: earned, workedSeconds: worked)
        resetTickCache()
    }

    /// "Resume Work Early" / "Skip Break" — log the break actually taken and loop back to work.
    public func resumeWork() {
        guard case .onBreak(_, _, let worked) = phase else { return }
        record(work: worked, rest: breakElapsed)
        startWork()
    }

    /// Leaves the loop entirely; logs whatever the current phase has accumulated.
    public func endSession() {
        switch phase {
        case .idle:
            return
        case .working:
            record(work: workElapsed, rest: 0)
        case .onBreak(_, _, let worked):
            record(work: worked, rest: breakElapsed)
        }
        flashUntil = nil
        phase = .idle
        resetTickCache()
    }

    // MARK: - Tick

    private func tick() {
        let elapsedInPhase: TimeInterval
        switch phase {
        case .idle:    elapsedInPhase = 0
        case .working: elapsedInPhase = workElapsed
        case .onBreak: elapsedInPhase = breakElapsed
        }

        // Expiry is checked against the real clock, not against a counter.
        if case .onBreak(_, let duration, let worked) = phase, elapsedInPhase >= duration {
            notifier.breakFinished(workSeconds: worked, breakSeconds: duration)
            record(work: worked, rest: duration)
            flashUntil = Date().addingTimeInterval(6)
            phase = .working(since: .now)
            resetTickCache()
            now = .now
            return
        }

        // Only publish when the visible second changes, to avoid needless redraws.
        let second = Int(elapsedInPhase)
        if second != lastDisplayedSecond || isFlashing {
            lastDisplayedSecond = second
            now = .now
        }
    }

    private func resetTickCache() {
        lastDisplayedSecond = -1
        now = .now
    }

    private func record(work: TimeInterval, rest: TimeInterval) {
        guard work >= 1 else { return }  // ignore accidental taps
        let session = Session(startedAt: Date().addingTimeInterval(-(work + rest) / timeScale),
                              workSeconds: work,
                              breakSeconds: rest)
        sessions.append(session)
        store.save(sessions)
    }
}
