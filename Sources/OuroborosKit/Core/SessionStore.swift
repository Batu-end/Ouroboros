import Foundation

/// Codable session history in `UserDefaults`. Small, append-only, pruned to a rolling window.
public final class SessionStore: @unchecked Sendable {

    private let key = "ouroboros.sessions.v1"
    private let retention: TimeInterval = 60 * 24 * 60 * 60  // 60 days
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [Session] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Session].self, from: data)
        else { return [] }
        let cutoff = Date().addingTimeInterval(-retention)
        return decoded.filter { $0.startedAt > cutoff }.sorted { $0.startedAt < $1.startedAt }
    }

    public func save(_ sessions: [Session]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: key)
    }
}

public extension Array where Element == Session {
    /// Only the sessions that started today, newest last.
    var today: [Session] {
        filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var totalWork: TimeInterval { reduce(0) { $0 + $1.workSeconds } }
    var totalBreak: TimeInterval { reduce(0) { $0 + $1.breakSeconds } }
}
