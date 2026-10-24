import CoreGraphics
import XCTest
@testable import ScrollSplit

final class ScrollTapTests: XCTestCase {
    private func scroll(lines: Int32, phase: Int64 = 0, momentum: Int64 = 0) -> CGEvent {
        let e = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: lines, wheel2: 1, wheel3: 0)!
        e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
        return e
    }

    func testWheelWithoutPhaseIsMouse() {
        XCTAssertEqual(ScrollTap.device(of: scroll(lines: 3)), .mouse)
    }

    func testPhasedScrollIsTrackpad() {
        XCTAssertEqual(ScrollTap.device(of: scroll(lines: 3, phase: 2)), .trackpad)       // changed
        XCTAssertEqual(ScrollTap.device(of: scroll(lines: 3, momentum: 2)), .trackpad)    // momentum continue
    }

    func testReverseNegatesEveryRepresentation() {
        let e = scroll(lines: 3)
        let before = (e.getIntegerValueField(.scrollWheelEventDeltaAxis1), e.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
                      e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), e.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        XCTAssertNotEqual(before.0, 0)
        ScrollTap.reverse(e)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis1), -before.0)
        XCTAssertEqual(e.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), -before.1)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), -before.2)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis2), -before.3)
    }
}
