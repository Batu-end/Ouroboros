import Foundation

/// The three states the app can be in. Each case carries absolute anchors rather than
/// counters, so elapsed time is always recomputed from the clock and cannot drift
/// across sleep/wake or dropped timer ticks.
public enum AppPhase: Equatable, Sendable {
    case idle
    case working(since: Date)
    case onBreak(start: Date, duration: TimeInterval, workedSeconds: TimeInterval)
    /// The break has finished and the next work block is waiting on a deliberate click.
    /// Time spent here is counted as neither work nor break — it is simply not at the desk.
    case waiting(since: Date)

    public var isWorking: Bool { if case .working = self { return true }; return false }
    public var isOnBreak: Bool { if case .onBreak = self { return true }; return false }
    public var isWaiting: Bool { if case .waiting = self { return true }; return false }
    public var isIdle: Bool { self == .idle }

    /// True when no clock is accumulating, i.e. the app owes the user nothing.
    public var isDormant: Bool { isIdle || isWaiting }
}

/// One completed work block and the break that followed it.
public struct Session: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let workSeconds: TimeInterval
    public let breakSeconds: TimeInterval

    public init(id: UUID = UUID(), startedAt: Date, workSeconds: TimeInterval, breakSeconds: TimeInterval) {
        self.id = id
        self.startedAt = startedAt
        self.workSeconds = workSeconds
        self.breakSeconds = breakSeconds
    }
}
