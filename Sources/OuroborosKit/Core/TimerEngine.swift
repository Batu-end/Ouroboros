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

    /// Seconds worked in the current work block (counts up, open-ended), as last displayed.
    public var workElapsed: TimeInterval { workElapsed(at: now) }

    /// Seconds already spent in the current break, as last displayed.
    public var breakElapsed: TimeInterval { breakElapsed(at: now) }

    /// `now` lags by up to one displayed second, which is fine for the readout but wrong for
    /// recording a loop — transitions pass `Date()` here so the log keeps real durations.
    private func workElapsed(at reference: Date) -> TimeInterval {
        guard case .working(let since) = phase else { return 0 }
        return max(0, reference.timeIntervalSince(since) * timeScale)
    }

    private func breakElapsed(at reference: Date) -> TimeInterval {
        guard case .onBreak(let start, _, _) = phase else { return 0 }
        return max(0, reference.timeIntervalSince(start) * timeScale)
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

    /// `0...1` for the ring, sampled at an arbitrary instant.
    ///
    /// Break: one full circle spans the whole break, depleting to empty as it runs out.
    /// Work: one sweep per minute, since work here is open-ended and a bar toward an
    /// invented deadline would be a lie.
    public func ringProgress(at reference: Date) -> Double {
        switch phase {
        case .idle:
            return 0
        case .working:
            return workElapsed(at: reference).truncatingRemainder(dividingBy: 60) / 60
        case .onBreak(_, let duration, _):
            guard duration > 0 else { return 0 }
            return max(0, (duration - breakElapsed(at: reference)) / duration)
        }
    }

    /// The ring value as of the last published second.
    public var ringProgress: Double { ringProgress(at: now) }

    public var isFlashing: Bool {
        guard let flashUntil else { return false }
        return now < flashUntil
    }

    /// SF Symbol shown in the status bar, by phase.
    public var menuBarSymbol: String {
        if isFlashing { return "checkmark.circle.fill" }
        switch phase {
        case .idle:      return "infinity"
        case .working:   return "infinity.circle.fill"
        case .onBreak:   return "cup.and.saucer.fill"
        }
    }

    /// Text beside the symbol. Empty while idle, so the status item stays a bare glyph.
    public var menuBarText: String {
        if isFlashing { return "back to it" }
        switch phase {
        case .idle:      return ""
        case .working:   return BreakMath.clock(workElapsed)
        case .onBreak:   return BreakMath.clock(breakRemaining)
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
        let worked = workElapsed(at: Date())
        let earned = BreakMath.earnedBreak(forWork: worked)
        phase = .onBreak(start: .now, duration: earned, workedSeconds: worked)
        resetTickCache()
    }

    /// "Resume Work Early" / "Skip Break" — log the break actually taken and loop back to work.
    public func resumeWork() {
        guard case .onBreak(_, _, let worked) = phase else { return }
        record(work: worked, rest: breakElapsed(at: Date()))
        startWork()
    }

    /// Leaves the loop entirely; logs whatever the current phase has accumulated.
    public func endSession() {
        switch phase {
        case .idle:
            return
        case .working:
            record(work: workElapsed(at: Date()), rest: 0)
        case .onBreak(_, _, let worked):
            record(work: worked, rest: breakElapsed(at: Date()))
        }
        flashUntil = nil
        phase = .idle
        resetTickCache()
    }

    // MARK: - Tick

    private func tick() {
        // Read the wall clock directly. Deriving this from `now` would be circular: `now`
        // only moves when the displayed second changes, so elapsed time would be measured
        // against a timestamp that never advances and the readout would freeze at 0:00.
        let current = Date()

        switch phase {
        case .idle:
            publish(second: 0, at: current)

        case .working(let since):
            publish(second: Int(max(0, current.timeIntervalSince(since) * timeScale)), at: current)

        case .onBreak(let start, let duration, let worked):
            let elapsed = max(0, current.timeIntervalSince(start) * timeScale)
            guard elapsed < duration else {
                closeLoop(worked: worked, duration: duration)
                return
            }
            publish(second: Int(elapsed), at: current)
        }
    }

    /// The break ran out: announce it, log the loop, and start the next work block.
    private func closeLoop(worked: TimeInterval, duration: TimeInterval) {
        notifier.breakFinished(workSeconds: worked, breakSeconds: duration)
        record(work: worked, rest: duration)
        flashUntil = Date().addingTimeInterval(6)
        phase = .working(since: .now)
        resetTickCache()
    }

    /// Publishes at most once per visible second, to avoid needless redraws.
    private func publish(second: Int, at current: Date) {
        guard second != lastDisplayedSecond || isFlashing else { return }
        lastDisplayedSecond = second
        now = current
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
