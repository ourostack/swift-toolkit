//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import UIKit
import XCTest

@MainActor
class PaginationViewDetachTests: XCTestCase {
    private final class Page: UIView, PageView {
        func go(to location: PageLocation, animated: Bool) async {}
    }

    private final class Pages: PaginationViewDelegate {
        var made = 0

        func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)? {
            made += 1
            return Page()
        }

        func paginationViewDidUpdateViews(_ paginationView: PaginationView) {}

        func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int { 1 }
    }

    private func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    /// A page made once the view is out of its superview would never be
    /// removed, and its web view would stay alive for good.
    func testADetachedPaginationViewMakesNoPages() async {
        let pages = Pages()
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let pagination = PaginationView(
            frame: superview.bounds,
            preloadPreviousPositionCount: 0,
            preloadNextPositionCount: 0,
            isScrollEnabled: true
        )
        pagination.delegate = pages
        superview.addSubview(pagination)

        pagination.reloadAtIndex(0, location: .start, pageCount: 3, readingProgression: .ltr)
        await settle()
        XCTAssertEqual(pages.made, 1, "attached, it makes the current page")

        pagination.removeFromSuperview()
        XCTAssertTrue(pagination.isEmpty)

        pagination.reloadAtIndex(1, location: .start, pageCount: 3, readingProgression: .ltr)
        await settle()
        XCTAssertEqual(pages.made, 1, "detached, it makes no page")
        XCTAssertTrue(pagination.isEmpty)
    }
}
