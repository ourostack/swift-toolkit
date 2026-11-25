//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import XCTest

/// A new spread view takes a web view whose page process is already running,
/// so a far jump never waits on a cold one.
@MainActor
class SpareWebViewTests: XCTestCase {
    private final class View {
        let number: Int
        init(_ number: Int) { self.number = number }
    }

    private var made = 0
    /// The warm-up of each view made, ended by the test.
    private var warmUps: [Int: () -> Void] = [:]

    private func spare() -> SpareWebView<View> {
        SpareWebView(
            make: { [unowned self] in
                made += 1
                return View(made)
            },
            warm: { [unowned self] view, done in
                warmUps[view.number] = done
                return nil
            }
        )
    }

    /// The first spread finds no spare, and starts one for the next.
    func testTheFirstTakeFindsNoneAndStartsOne() {
        let spares = spare()
        XCTAssertNil(spares.take())
        XCTAssertEqual(made, 1)
    }

    /// Once its warm-up load has finished, the spare is what the next spread
    /// gets, and the one after it is started.
    func testAWarmedSpareIsTakenAndReplaced() throws {
        let spares = spare()
        _ = spares.take()
        try XCTUnwrap(warmUps[1])()
        XCTAssertEqual(spares.take()?.number, 1)
        XCTAssertEqual(made, 2, "the next spare is started as soon as this one is taken")
    }

    /// A spare still warming is never handed out: its warm-up load would reach
    /// the spread view's navigation delegate.
    func testASpareStillWarmingIsNotHandedOut() {
        let spares = spare()
        _ = spares.take()
        XCTAssertNil(spares.take())
        XCTAssertEqual(made, 1, "no second spare while the first is still warming")
    }

    /// Closed with its navigator, it lets go of the spare and makes no more.
    func testClosedItHoldsNoneAndMakesNoMore() throws {
        let spares = spare()
        _ = spares.take()
        try XCTUnwrap(warmUps[1])()
        spares.close()
        XCTAssertNil(spares.take())
        XCTAssertEqual(made, 1)
    }
}
