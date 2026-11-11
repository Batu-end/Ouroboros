import AppKit
import XCTest
@testable import OuroborosKit

final class BreakMathTests: XCTestCase {

    func testEarnedBreakIsEighteenPercent() {
        XCTAssertEqual(BreakMath.earnedBreak(forWork: 3600), 648, accuracy: 0.001)   // 1h → 10:48
        XCTAssertEqual(BreakMath.earnedBreak(forWork: 1500), 270, accuracy: 0.001)   // 25m → 4:30
    }

    func testMinimumBreakFloor() {
        XCTAssertEqual(BreakMath.earnedBreak(forWork: 0), 60)
        XCTAssertEqual(BreakMath.earnedBreak(forWork: 120), 60)      // 21.6s earned → floored
        XCTAssertEqual(BreakMath.earnedBreak(forWork: -500), 60)     // nonsense input stays safe
    }

    func testFloorAppliesExactlyAtTheCrossover() {
        // 60s / 0.18 = 333.33s of work is where the ratio overtakes the floor.
        XCTAssertEqual(BreakMath.earnedBreak(forWork: 330), 60)
        XCTAssertGreaterThan(BreakMath.earnedBreak(forWork: 340), 60)
    }

    func testClockFormatting() {
        XCTAssertEqual(BreakMath.clock(0), "0:00")
        XCTAssertEqual(BreakMath.clock(-9), "0:00")
        XCTAssertEqual(BreakMath.clock(65), "1:05")
        XCTAssertEqual(BreakMath.clock(865), "14:25")
        XCTAssertEqual(BreakMath.clock(3725), "1:02:05")
        XCTAssertEqual(BreakMath.clock(59.9), "0:59")   // truncates, never rounds up to 1:00
    }

    func testHumaneFormatting() {
        XCTAssertEqual(BreakMath.humane(45), "45s")
        XCTAssertEqual(BreakMath.humane(865), "14m")
        XCTAssertEqual(BreakMath.humane(8040), "2h 14m")
        XCTAssertEqual(BreakMath.humane(7200), "2h")
    }

    func testRatioLabel() {
        XCTAssertEqual(BreakMath.ratioLabel(work: 1000, rest: 180), "18%")
        XCTAssertEqual(BreakMath.ratioLabel(work: 0, rest: 0), "—")
    }
}

@MainActor
final class TimerEngineTests: XCTestCase {

    private func engine() -> TimerEngine {
        let defaults = UserDefaults(suiteName: "ouroboros.tests.\(UUID().uuidString)")!
        return TimerEngine(store: SessionStore(defaults: defaults), timeScale: 1)
    }

    func testStartsIdle() {
        XCTAssertTrue(engine().phase.isIdle)
    }

    func testWorkToBreakBanksEarnedTime() {
        let e = engine()
        e.startWork()
        XCTAssertTrue(e.phase.isWorking)

        e.takeBreak()
        guard case .onBreak(_, let duration, _) = e.phase else {
            return XCTFail("expected a break phase")
        }
        XCTAssertEqual(duration, 60)            // ~0s of work → the 60s floor
        XCTAssertEqual(e.breakDuration, 60)
    }

    func testResumingEarlyLogsTheLoopAndReturnsToWork() {
        let e = engine()
        e.startWork()
        e.takeBreak()
        e.resumeWork()

        XCTAssertTrue(e.phase.isWorking)
        XCTAssertEqual(e.sessions.count, 0, "a sub-second work block is not worth logging")
    }

    func testEndSessionReturnsToIdle() {
        let e = engine()
        e.startWork()
        e.endSession()
        XCTAssertTrue(e.phase.isIdle)
    }

    /// The expiry path: break runs out on the wall clock, the loop is logged, work resumes.
    /// `timeScale: 600` makes a 60s break elapse in 0.1s of real time.
    func testBreakExpiryLogsTheLoopAndResumesWork() async throws {
        let defaults = UserDefaults(suiteName: "ouroboros.tests.\(UUID().uuidString)")!
        let e = TimerEngine(store: SessionStore(defaults: defaults), timeScale: 600)

        e.startWork()
        try await Task.sleep(for: .milliseconds(600))   // ~360s of virtual work
        e.takeBreak()
        guard case .onBreak(_, let duration, let worked) = e.phase else {
            return XCTFail("expected a break phase")
        }
        XCTAssertGreaterThan(worked, 300)
        XCTAssertEqual(duration, BreakMath.earnedBreak(forWork: worked), accuracy: 0.001)

        try await Task.sleep(for: .milliseconds(900))   // long enough for the break to run out

        XCTAssertTrue(e.phase.isWorking, "break should auto-return to work")
        XCTAssertEqual(e.sessions.count, 1)
        let logged = try XCTUnwrap(e.sessions.first)
        XCTAssertEqual(logged.breakSeconds, duration, accuracy: 0.001, "full break was taken")
        XCTAssertEqual(logged.workSeconds, worked, accuracy: 0.001)
        XCTAssertNotNil(e.flashUntil, "menu bar fallback announcement was armed")
    }

    /// Regression: the tick used to measure elapsed time against its own published
    /// timestamp, which only moved when the displayed second changed — so at normal speed
    /// the readout froze at 0:00 forever. Fast mode hid it, because the large scale factor
    /// always pushed the second over.
    func testClockActuallyAdvancesAtRealSpeed() async throws {
        let defaults = UserDefaults(suiteName: "ouroboros.tests.\(UUID().uuidString)")!
        let e = TimerEngine(store: SessionStore(defaults: defaults), timeScale: 1)

        e.startWork()
        try await Task.sleep(for: .milliseconds(1300))

        XCTAssertGreaterThanOrEqual(e.workElapsed, 1, "work clock must advance in real time")
        XCTAssertEqual(e.menuBarText, BreakMath.clock(e.workElapsed))
        XCTAssertNotEqual(e.menuBarText, "0:00")
    }

    /// Every SF Symbol the status item asks for must exist on this OS.
    func testMenuBarSymbolsResolve() {
        let defaults = UserDefaults(suiteName: "ouroboros.tests.\(UUID().uuidString)")!
        let e = TimerEngine(store: SessionStore(defaults: defaults), timeScale: 1)

        XCTAssertNotNil(NSImage(systemSymbolName: e.menuBarSymbol, accessibilityDescription: nil))
        e.startWork()
        XCTAssertEqual(e.menuBarSymbol, "infinity.circle.fill")
        XCTAssertNotNil(NSImage(systemSymbolName: e.menuBarSymbol, accessibilityDescription: nil))
        e.takeBreak()
        XCTAssertEqual(e.menuBarSymbol, "cup.and.saucer.fill")
        XCTAssertNotNil(NSImage(systemSymbolName: e.menuBarSymbol, accessibilityDescription: nil))
    }

    /// The drawn status item must have real pixels, or the menu bar shows nothing.
    func testStatusItemImageHasSize() {
        let withText = StatusItemImage.make(symbol: "infinity.circle.fill", text: "14:25")
        XCTAssertGreaterThan(withText.size.width, 20)
        XCTAssertGreaterThan(withText.size.height, 0)
        XCTAssertTrue(withText.isTemplate)

        let bare = StatusItemImage.make(symbol: "infinity", text: "")
        XCTAssertGreaterThan(bare.size.width, 8)
    }

    /// The break ring is one full circle across the whole break, not a per-minute sweep.
    func testBreakRingSpansTheWholeBreak() {
        let defaults = UserDefaults(suiteName: "ouroboros.tests.\(UUID().uuidString)")!
        let e = TimerEngine(store: SessionStore(defaults: defaults), timeScale: 1)
        e.startWork()
        e.takeBreak()

        guard case .onBreak(let start, let duration, _) = e.phase else {
            return XCTFail("expected a break phase")
        }
        XCTAssertEqual(e.ringProgress(at: start), 1.0, accuracy: 0.01, "full at the start")
        XCTAssertEqual(e.ringProgress(at: start.addingTimeInterval(duration / 2)), 0.5, accuracy: 0.01)
        XCTAssertEqual(e.ringProgress(at: start.addingTimeInterval(duration)), 0.0, accuracy: 0.01)
        XCTAssertEqual(e.ringProgress(at: start.addingTimeInterval(duration * 2)), 0.0, accuracy: 0.01)
    }

    /// The work ring sweeps once a minute, and the samples between seconds are distinct —
    /// which is what makes the motion continuous rather than stepped.
    func testWorkRingSweepsOncePerMinuteAndIsContinuous() {
        let defaults = UserDefaults(suiteName: "ouroboros.tests.\(UUID().uuidString)")!
        let e = TimerEngine(store: SessionStore(defaults: defaults), timeScale: 1)
        e.startWork()
        guard case .working(let since) = e.phase else { return XCTFail("expected work") }

        XCTAssertEqual(e.ringProgress(at: since.addingTimeInterval(30)), 0.5, accuracy: 0.01)
        XCTAssertEqual(e.ringProgress(at: since.addingTimeInterval(59.99)), 1.0, accuracy: 0.01)
        XCTAssertEqual(e.ringProgress(at: since.addingTimeInterval(60)), 0.0, accuracy: 0.01, "wraps")
        XCTAssertEqual(e.ringProgress(at: since.addingTimeInterval(90)), 0.5, accuracy: 0.01)

        let a = e.ringProgress(at: since.addingTimeInterval(10.1))
        let b = e.ringProgress(at: since.addingTimeInterval(10.6))
        XCTAssertNotEqual(a, b, "sub-second samples must differ")
    }

    /// The Today list: a closed loop lands in it and survives a relaunch.
    func testClosedLoopAppearsInTodayAndPersists() async throws {
        let suite = "ouroboros.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let e = TimerEngine(store: SessionStore(defaults: defaults), timeScale: 600)

        e.startWork()
        try await Task.sleep(for: .milliseconds(400))
        e.takeBreak()
        try await Task.sleep(for: .milliseconds(100))
        e.resumeWork()

        XCTAssertEqual(e.sessions.today.count, 1)
        XCTAssertGreaterThan(e.sessions.today.totalWork, 0)
        XCTAssertGreaterThan(e.sessions.today.totalBreak, 0)

        // A fresh engine over the same storage sees it, as it would after a relaunch.
        let reopened = TimerEngine(store: SessionStore(defaults: defaults), timeScale: 1)
        XCTAssertEqual(reopened.sessions.today.count, 1)
    }

    func testTransitionsIgnoreWrongPhase() {
        let e = engine()
        e.takeBreak()           // nothing to bank from idle
        XCTAssertTrue(e.phase.isIdle)
        e.resumeWork()          // no break in progress
        XCTAssertTrue(e.phase.isIdle)
    }
}
