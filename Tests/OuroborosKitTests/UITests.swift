import AppKit
import SwiftUI
import XCTest
@testable import OuroborosKit

/// The ring is the one part of the app a unit test cannot see, and the two ways it can die
/// silently are a stuck overlay and a visibility gate that never opens. Both are covered here.
@MainActor
final class RingRenderTests: XCTestCase {

    /// The arc at rest must be a quarter sweep, not a full ring: the milestone flash used to
    /// rest at 85% opacity and cover the arc completely.
    func testProgressArcIsVisibleAndNotCoveredByTheFlash() throws {
        let view = ZStack {
            RingArc(progress: 0.25, accent: Theme.work)   // a quarter sweep: top-right only
            MilestoneFlash(pulse: 0, accent: Theme.work)  // at rest: must contribute nothing
        }
        let image = try render(view)

        // The arc covers the top-right quadrant. The grey track is drawn all the way round,
        // so the test looks for *accent-coloured* pixels specifically: anywhere outside the
        // swept quadrant must carry only track grey. A full-ring overlay breaks this.
        XCTAssertTrue(isAccented(image, x: 148, y: 74), "the arc should be drawn at 3 o'clock")
        XCTAssertFalse(isAccented(image, x: 4, y: 74), "no accent at 9 o'clock for a 25% sweep")
        XCTAssertFalse(isAccented(image, x: 74, y: 148), "no accent at 6 o'clock for a 25% sweep")
    }

    /// The arc's leading cap must be the same shade as the arc body. It used to be painted
    /// by the faded end of the angular gradient, which read as a pale blob at 12 o'clock.
    func testArcStartMatchesTheArcBody() throws {
        let image = try render(RingArc(progress: 0.5, accent: Theme.work))

        let cap = try XCTUnwrap(accentColour(image, x: 76, y: 4))      // 12 o'clock: the start
        let body = try XCTUnwrap(accentColour(image, x: 148, y: 76))   // 3 o'clock: mid-arc

        // The cap is where the gradient wrapped, so it used to be drawn at 55% opacity over
        // the grey track — a pale blob. It must now be at least as solid as the arc body.
        XCTAssertGreaterThan(cap.alphaComponent, 0.9, "the leading cap must be fully opaque")
        XCTAssertGreaterThanOrEqual(cap.saturationComponent, body.saturationComponent - 0.05,
                                    "the leading cap must not be washed out")
    }

    /// And a firing flash must be visible, or the micro-reward never lands. (That it is
    /// *invisible* at rest is covered above, where it is composited over the arc — the case
    /// that actually regressed. Rendering it alone here would be flaky: successive
    /// `ImageRenderer`s in one test process sometimes return the previous view's image.)
    func testFiringFlashIsVisible() throws {
        let firing = accentPixelCount(try render(MilestoneFlash(pulse: 1, accent: Theme.work)))
        XCTAssertGreaterThan(firing, 200, "a firing flash must actually be drawn")
    }

    func testFullSweepInksTheWholeRing() throws {
        let view = RingArc(progress: 1.0, accent: Theme.rest)
        let image = try render(view)
        XCTAssertTrue(isAccented(image, x: 148, y: 74))
        XCTAssertTrue(isAccented(image, x: 4, y: 74))
        XCTAssertTrue(isAccented(image, x: 74, y: 148))
    }

    /// The most saturated pixel near (x, y), i.e. the arc itself rather than its shadow.
    private func accentColour(_ image: NSBitmapImageRep, x: Int, y: Int) -> NSColor? {
        var best: NSColor?
        for dx in -5...5 {
            for dy in -5...5 {
                let sx = min(max(x + dx, 0), image.pixelsWide - 1)
                let sy = min(max(y + dy, 0), image.pixelsHigh - 1)
                guard let colour = image.colorAt(x: sx, y: sy)?.usingColorSpace(.deviceRGB),
                      colour.alphaComponent > 0.5, colour.saturationComponent > 0.25
                else { continue }
                if best == nil || colour.saturationComponent > best!.saturationComponent {
                    best = colour
                }
            }
        }
        return best
    }

    /// How much accent-coloured paint the whole image carries. Counting beats sampling a
    /// single point when the question is "is this drawn at all".
    private func accentPixelCount(_ image: NSBitmapImageRep) -> Int {
        var count = 0
        for x in stride(from: 0, to: image.pixelsWide, by: 2) {
            for y in stride(from: 0, to: image.pixelsHigh, by: 2) {
                guard let colour = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if colour.alphaComponent > 0.3 && colour.saturationComponent > 0.25 { count += 1 }
            }
        }
        return count
    }

    nonisolated(unsafe) static var renderIndex = 0

    // MARK: Helpers

    private func render(_ view: some View) throws -> NSBitmapImageRep {
        // `.id(UUID())` forces a fresh identity per render: inside one test process,
        // successive ImageRenderers can otherwise hand back the previous view's image.
        let renderer = ImageRenderer(content: view.frame(width: 152, height: 152).id(UUID()))
        renderer.scale = 1
        let cg = try XCTUnwrap(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: cg)
        // Dropped next to the build so a human (or Claude) can look at what the test saw.
        if let png = bitmap.representation(using: .png, properties: [:]) {
            let name = "ouroboros-ring-\(Self.renderIndex).png"
            Self.renderIndex += 1
            try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + name))
        }
        return bitmap
    }

    /// True when a pixel near (x, y) carries saturated colour, i.e. the accent arc rather
    /// than the grey track or the transparent background.
    private func isAccented(_ image: NSBitmapImageRep, x: Int, y: Int) -> Bool {
        let px = min(max(x, 0), image.pixelsWide - 1)
        let py = min(max(y, 0), image.pixelsHigh - 1)
        for dx in -3...3 {
            for dy in -3...3 {
                let sx = min(max(px + dx, 0), image.pixelsWide - 1)
                let sy = min(max(py + dy, 0), image.pixelsHigh - 1)
                guard let colour = image.colorAt(x: sx, y: sy)?
                    .usingColorSpace(.deviceRGB) else { continue }
                if colour.alphaComponent > 0.3 && colour.saturationComponent > 0.25 {
                    return true
                }
            }
        }
        return false
    }
}

/// The CPU fix hinges on this probe: if it reported "hidden" while the popover is open, the
/// ring would silently stop moving.
@MainActor
final class WindowVisibilityTests: XCTestCase {

    func testProbeTracksWhetherTheWindowIsOnScreen() throws {
        let probe = WindowVisibility.ProbeView()
        var latest: Bool?
        probe.onChange = { latest = $0 }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 160),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        try XCTUnwrap(window.contentView).addSubview(probe)

        window.makeKeyAndOrderFront(nil)
        probe.report()
        XCTAssertEqual(latest, true, "an on-screen window must keep the ring animating")

        window.orderOut(nil)
        probe.report()
        XCTAssertEqual(latest, false, "a closed popover must pause the ring")
    }

    func testProbeReportsHiddenWithoutAWindow() {
        let probe = WindowVisibility.ProbeView()
        var latest: Bool?
        probe.onChange = { latest = $0 }
        probe.report()
        XCTAssertEqual(latest, false)
    }
}
