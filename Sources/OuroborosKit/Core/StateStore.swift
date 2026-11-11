import Foundation

/// Crash-safe snapshot of the live phase, written on every transition.
///
/// `heartbeat` is refreshed while the app runs, so a restore can tell the difference between
/// "relaunched a second after a crash" (resume exactly where we were) and "the Mac rebooted
/// two hours ago" (close the block at the last heartbeat, never invent the missing time).
struct PhaseSnapshot: Codable, Equatable {
    enum Kind: String, Codable { case working, onBreak, waiting }

    var kind: Kind
    var anchor: Date              // work start, or break start
    var duration: TimeInterval    // break length; unused while working
    var workedSeconds: TimeInterval
    var heartbeat: Date

    var phase: AppPhase {
        switch kind {
        case .working: return .working(since: anchor)
        case .onBreak: return .onBreak(start: anchor, duration: duration, workedSeconds: workedSeconds)
        case .waiting: return .waiting(since: anchor)
        }
    }

    init?(phase: AppPhase, heartbeat: Date) {
        switch phase {
        case .idle:
            return nil
        case .working(let since):
            self.kind = .working
            self.anchor = since
            self.duration = 0
            self.workedSeconds = 0
        case .onBreak(let start, let duration, let worked):
            self.kind = .onBreak
            self.anchor = start
            self.duration = duration
            self.workedSeconds = worked
        case .waiting(let since):
            self.kind = .waiting
            self.anchor = since
            self.duration = 0
            self.workedSeconds = 0
        }
        self.heartbeat = heartbeat
    }
}

/// Everything that must outlive the process: the live phase and the user's break setting.
public final class StateStore: @unchecked Sendable {

    private let phaseKey = "ouroboros.phase.v1"
    private let generosityKey = "ouroboros.generosity.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Phase

    func savePhase(_ snapshot: PhaseSnapshot?) {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
            defaults.removeObject(forKey: phaseKey)
            return
        }
        defaults.set(data, forKey: phaseKey)
    }

    func loadPhase() -> PhaseSnapshot? {
        guard let data = defaults.data(forKey: phaseKey) else { return nil }
        return try? JSONDecoder().decode(PhaseSnapshot.self, from: data)
    }

    // MARK: Settings

    public var generosity: BreakGenerosity {
        get {
            guard let raw = defaults.string(forKey: generosityKey),
                  let value = BreakGenerosity(rawValue: raw)
            else { return .standard }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: generosityKey) }
    }
}
