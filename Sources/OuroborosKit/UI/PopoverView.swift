import SwiftUI

/// The whole dashboard: one readout, one decision, one honest log.
public struct PopoverView: View {
    @ObservedObject var engine: TimerEngine

    public init(engine: TimerEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: Theme.gutter) {
            header

            TimerRing(
                phase: engine.phase,
                progress: engine.ringProgress,
                primary: primaryReadout,
                caption: captionText
            )
            .padding(.top, 2)

            VStack(spacing: 8) {
                primaryButton
                secondaryRow
            }

            Divider().opacity(0.5)

            SessionLogView(sessions: engine.sessions.today)
        }
        .padding(Theme.gutter)
        .frame(width: Theme.popoverWidth)
        .background(.ultraThinMaterial)
        .animation(Theme.phaseChange, value: engine.phase)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.accent(for: engine.phase))
            Text("OUROBOROS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Spacer()

            Text(phaseLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.accent(for: engine.phase).opacity(0.16), in: Capsule())
                .foregroundStyle(Theme.accent(for: engine.phase))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .help("Quit Ouroboros")
        }
    }

    private var primaryButton: some View {
        Group {
            switch engine.phase {
            case .idle:
                PrimaryActionButton(title: "Start Working", systemImage: "play.fill", tint: Theme.work) {
                    engine.startWork()
                }
            case .working:
                PrimaryActionButton(title: "I'm Distracted — Take Break", systemImage: "cup.and.saucer.fill", tint: Theme.rest) {
                    engine.takeBreak()
                }
            case .onBreak:
                PrimaryActionButton(title: "Resume Work Early", systemImage: "briefcase.fill", tint: Theme.work) {
                    engine.resumeWork()
                }
            }
        }
    }

    private var secondaryRow: some View {
        HStack {
            if engine.phase.isOnBreak {
                SubtleButton(title: "Skip Break") { engine.resumeWork() }
            }
            Spacer()
            if !engine.phase.isIdle {
                SubtleButton(title: "End Session") { engine.endSession() }
            }
        }
        .frame(height: 14)
    }

    // MARK: - Copy

    private var phaseLabel: String {
        switch engine.phase {
        case .idle:    return "IDLE"
        case .working: return "WORKING"
        case .onBreak: return "ON BREAK"
        }
    }

    private var primaryReadout: String {
        switch engine.phase {
        case .idle:    return "0:00"
        case .working: return BreakMath.clock(engine.workElapsed)
        case .onBreak: return BreakMath.clock(engine.breakRemaining)
        }
    }

    private var captionText: String {
        switch engine.phase {
        case .idle:
            return "ready when you are"
        case .working:
            return "banked \(BreakMath.clock(engine.bankedBreak)) break"
        case .onBreak:
            return "\(BreakMath.humane(engine.breakDuration)) from \(BreakMath.humane(engine.breakSourceWork)) worked"
        }
    }
}
