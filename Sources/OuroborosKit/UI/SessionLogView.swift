import SwiftUI

/// Today's cycles — one work block plus the break that followed it, recorded when the
/// break closes. What you actually worked, and what you actually rested.
struct SessionLogView: View {
    let sessions: [Session]

    private static let rowHeight: CGFloat = 29
    private static let maxListHeight: CGFloat = 132

    /// Tall enough for the rows there are, never taller than the popover can spare.
    static func listHeight(for count: Int) -> CGFloat {
        min(CGFloat(max(count, 1)) * rowHeight, maxListHeight)
    }

    private static let timeFormat: Date.FormatStyle =
        .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.8)
                Spacer()
                if !sessions.isEmpty {
                    Text("\(sessions.count) cycle\(sessions.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            if sessions.isEmpty {
                Text("No cycles closed yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .card()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sessions.reversed()) { session in
                            row(session)
                            if session.id != sessions.first?.id {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
                // A definite height, not `maxHeight`: a ScrollView has no ideal height of
                // its own, so inside a popover that sizes itself to fit, a cap alone let it
                // collapse to nothing — the day's cycles were counted but never listed.
                .frame(height: Self.listHeight(for: sessions.count))
                .card()

                totals
            }
        }
    }

    private func row(_ session: Session) -> some View {
        HStack(spacing: 8) {
            Text(session.startedAt.formatted(Self.timeFormat))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 62, alignment: .leading)

            Label(BreakMath.humane(session.workSeconds), systemImage: "briefcase.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.work)
                .labelStyle(.titleAndIcon)

            Spacer(minLength: 4)

            Label(BreakMath.humane(session.breakSeconds), systemImage: "cup.and.saucer.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.rest)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var totals: some View {
        HStack(spacing: 0) {
            stat("Worked", BreakMath.humane(sessions.totalWork), Theme.work)
            Divider().frame(height: 22).opacity(0.4)
            stat("Rested", BreakMath.humane(sessions.totalBreak), Theme.rest)
            Divider().frame(height: 22).opacity(0.4)
            stat("Ratio", BreakMath.ratioLabel(work: sessions.totalWork, rest: sessions.totalBreak), .secondary)
        }
        .padding(.vertical, 8)
        .card()
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
