import AppKit
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

    /// Whole 10-minute blocks completed in the current work stretch. The ring pulses when
    /// this changes — a small, cheap hit of "that counted".
    @Published public private(set) var milestone: Int = 0

    /// Published when a break runs out, so the UI can put the hand-off in front of the user.
    @Published public private(set) var breakCompletion: BreakCompletion?

    /// Called the moment a break ends. This is a hook rather than a view-side `onChange`
    /// because the popover does not exist while it is closed — which is exactly when the
    /// hand-off matters most.
    public var onBreakCompleted: ((BreakCompletion) -> Void)?

    /// How generous the break ratio is. Persisted immediately.
    @Published public var generosity: BreakGenerosity {
        didSet {
            guard oldValue != generosity else { return }
            state.generosity = generosity
        }
    }

    /// `1` normally. `OUROBOROS_FAST=1` makes one real second count as a minute, which
    /// makes the full work → break → work loop exercisable in seconds.
    public let timeScale: Double

    public struct BreakCompletion: Equatable, Identifiable {
        public let id = UUID()
        public let workSeconds: TimeInterval
        public let breakSeconds: TimeInterval
    }

    private let store: SessionStore
    private let state: StateStore
    private let notifier: NotificationManager
    private var ticker: AnyCancellable?
    // Held for the process lifetime: the engine is the app, so there is nothing to tear down.
    private var wakeObserver: (any NSObjectProtocol)?
    private var lastDisplayedSecond = -1
    private var lastHeartbeat: Date = .distantPast

    /// How long a gap in heartbeats means the app was not running. Anything longer and the
    /// missing time is never counted as work.
    private let staleAfter: TimeInterval = 90

    public init(
        store: SessionStore = SessionStore(),
        state: StateStore = StateStore(),
        notifier: NotificationManager = NotificationManager(),
        timeScale: Double? = nil
    ) {
        self.store = store
        self.state = state
        self.notifier = notifier
        self.timeScale = timeScale ?? (ProcessInfo.processInfo.environment["OUROBOROS_FAST"] == "1" ? 60 : 1)
        self.sessions = store.load()
        self.generosity = state.generosity

        notifier.prepare()
        restorePhase()
        observeWake()
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
        phase.isWorking ? BreakMath.earnedBreak(forWork: workElapsed, ratio: generosity.ratio) : 0
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

    // MARK: - Status item

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

    /// Used by the break-over panel: work has already restarted by then, so this must not
    /// reset the clock — it only covers the case where the user ended the session meanwhile.
    public func ensureWorking() {
        guard phase.isIdle else { return }
        startWork()
    }

    public func startWork() {
        flashUntil = nil
        breakCompletion = nil
        phase = .working(since: .now)
        milestone = 0
        resetTickCache()
        persistPhase()
        startTicking()
    }

    /// "I'm Distracted / Take Break" — bank a slice of what was actually worked.
    public func takeBreak() {
        guard case .working = phase else { return }
        let worked = workElapsed(at: Date())
        let earned = BreakMath.earnedBreak(forWork: worked, ratio: generosity.ratio)
        phase = .onBreak(start: .now, duration: earned, workedSeconds: worked)
        milestone = 0
        resetTickCache()
        persistPhase()
        startTicking()
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
        breakCompletion = nil
        milestone = 0
        phase = .idle
        resetTickCache()
        persistPhase()
        stopTicking()
    }

    // MARK: - Tick

    /// True while the per-second timer is running. Idle costs nothing at all.
    public var isTicking: Bool { ticker != nil }

    /// The ticker runs only while a phase is live, so an idle app costs nothing. One tick a
    /// second is plenty at normal speed; fast mode needs a finer grain to stay watchable.
    private func startTicking() {
        guard ticker == nil else { return }
        let interval = timeScale > 1 ? 0.05 : 0.5
        ticker = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        // Read the wall clock directly. Deriving this from `now` would be circular: `now`
        // only moves when the displayed second changes, so elapsed time would be measured
        // against a timestamp that never advances and the readout would freeze at 0:00.
        let current = Date()

        switch phase {
        case .idle:
            stopTicking()

        case .working(let since):
            let elapsed = max(0, current.timeIntervalSince(since) * timeScale)
            milestone = Int(elapsed / 600)
            publish(second: Int(elapsed), at: current)

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
        let completion = BreakCompletion(workSeconds: worked, breakSeconds: duration)
        breakCompletion = completion
        onBreakCompleted?(completion)
        flashUntil = Date().addingTimeInterval(6)
        phase = .working(since: .now)
        milestone = 0
        resetTickCache()
        persistPhase()
    }

    /// Publishes at most once per visible second, to avoid needless redraws.
    private func publish(second: Int, at current: Date) {
        guard second != lastDisplayedSecond || isFlashing else { return }
        lastDisplayedSecond = second
        now = current
        beat(at: current)
    }

    private func resetTickCache() {
        lastDisplayedSecond = -1
        now = .now
    }

    // MARK: - Persistence and restore

    /// A heartbeat every 15s is enough to tell a crash from a reboot, and cheap enough to
    /// be invisible.
    private func beat(at current: Date) {
        guard current.timeIntervalSince(lastHeartbeat) >= 15 else { return }
        lastHeartbeat = current
        persistPhase(heartbeat: current)
    }

    private func persistPhase(heartbeat: Date = Date()) {
        state.savePhase(PhaseSnapshot(phase: phase, heartbeat: heartbeat))
    }

    /// Brings back the live phase after a relaunch, crash or reboot.
    ///
    /// The rule is never to invent time: anything after the last heartbeat is time the app
    /// was not running, so it is cut rather than counted.
    private func restorePhase() {
        guard let snapshot = state.loadPhase() else { return }
        let gap = Date().timeIntervalSince(snapshot.heartbeat)
        let wasRunning = gap >= 0 && gap < staleAfter

        switch snapshot.kind {
        case .working:
            if wasRunning {
                phase = snapshot.phase          // seamless: a crash and a quick relaunch
                startTicking()
            } else {
                // Close the block at the last heartbeat; the gap was not work.
                let worked = max(0, snapshot.heartbeat.timeIntervalSince(snapshot.anchor) * timeScale)
                record(work: worked, rest: 0)
                phase = .idle
                persistPhase()
            }

        case .onBreak:
            let elapsed = max(0, Date().timeIntervalSince(snapshot.anchor) * timeScale)
            if wasRunning && elapsed < snapshot.duration {
                phase = snapshot.phase          // the break is still running; pick it up
                startTicking()
            } else {
                // The break finished while we were away. Log it, but do not pretend the
                // user has been working since.
                record(work: snapshot.workedSeconds, rest: min(elapsed, snapshot.duration))
                phase = .idle
                persistPhase()
            }
        }
        resetTickCache()
    }

    /// Waking from sleep can skip many ticks at once; resync the readout immediately so the
    /// menu bar is never stale for a second.
    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.phase.isIdle else { return }
                self.resetTickCache()
                self.tick()
            }
        }
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
