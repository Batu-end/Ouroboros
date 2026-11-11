import Foundation

/// Pure, testable rules behind the dynamic break ratio.
public enum BreakMath {

    /// Default fraction of worked time that is banked as break time.
    /// `BreakGenerosity` can raise or lower it per taste.
    public static let ratio: Double = BreakGenerosity.standard.ratio

    /// A break is never shorter than this, no matter how brief the work block was.
    public static let minimumBreak: TimeInterval = 60

    /// Break time earned by a work block, rounded to whole seconds and floored at `minimumBreak`.
    public static func earnedBreak(forWork work: TimeInterval, ratio: Double = ratio) -> TimeInterval {
        let earned = (max(0, work) * ratio).rounded()
        return max(minimumBreak, earned)
    }

    /// `14:25`, or `1:02:05` once an hour is passed. Always at least `0:00`.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// `2h 14m`, `14m`, `45s` — for totals, where seconds are noise.
    public static func humane(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded())
        if total < 60 { return "\(total)s" }
        let (h, m) = (total / 3600, (total % 3600) / 60)
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    /// Realized break ratio across a set of sessions, as a percentage string (`15%`).
    public static func ratioLabel(work: TimeInterval, rest: TimeInterval) -> String {
        guard work > 0 else { return "—" }
        return "\(Int((rest / work * 100).rounded()))%"
    }
}
