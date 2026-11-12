import SwiftUI

/// Today at a glance: how much was worked, how much was rested, and the ratio that actually
/// came out of it.
///
/// Every cycle — a work block plus the break that followed it — is still recorded and kept
/// for 60 days. It is deliberately not listed here: a scrolling ledger of the day is more
/// than this popover should ask anyone to read. The stored history is there for whatever
/// gets built on top of it later.
struct SessionLogView: View {
    let sessions: [Session]

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
                totals
            }
        }
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
