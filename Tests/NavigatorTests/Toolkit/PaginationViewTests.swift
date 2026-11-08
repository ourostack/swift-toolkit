//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import UIKit
import XCTest

@MainActor
final class PaginationViewTests: XCTestCase {
    /// A page whose `go(to:)` waits until the test releases it, like a slow resource.
    private final class SlowPage: UIView, PageView {
        var release: CheckedContinuation<Void, Never>?
        var isHeld = false

        func go(to location: PageLocation, animated: Bool) async {
            guard isHeld else { return }
            await withCheckedContinuation { release = $0 }
        }
    }

    private final class Delegate: PaginationViewDelegate {
        var pages: [Int: SlowPage] = [:]
        var held: Set<Int> = []
        var updates: [Set<Int>] = []

        func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)? {
            let page = SlowPage()
            page.isHeld = held.contains(index)
            pages[index] = page
            return page
        }

        func paginationViewDidUpdateViews(_ paginationView: PaginationView) {
            updates.append(Set(pages.keys))
        }

        func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int { 1 }
    }

    /// The current page is reported once it has loaded, while a pre-loaded neighbour is still loading.
    func testReportsTheCurrentPageBeforeThePreloadedNeighboursFinish() async throws {
        let delegate = Delegate()
        delegate.held = [2]
        let view = PaginationView(frame: CGRect(x: 0, y: 0, width: 300, height: 400), preloadPreviousPositionCount: 1, preloadNextPositionCount: 1, isScrollEnabled: true)
        view.delegate = delegate

        view.reloadAtIndex(1, location: .start, pageCount: 3, readingProgression: .ltr)

        for _ in 0 ..< 200 where delegate.updates.isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(delegate.updates.count, 1, "The current page wasn't reported while its next neighbour was still loading")
        XCTAssertNil(delegate.pages[0], "The previous neighbour loaded before the held next one")

        delegate.pages[2]?.release?.resume()
        for _ in 0 ..< 200 where delegate.updates.count < 2 {
            await Task.yield()
        }
        XCTAssertEqual(delegate.updates.count, 2, "The views weren't reported again once every neighbour loaded")
        XCTAssertEqual(delegate.updates.last, [0, 1, 2])
    }

    /// Opened with no pre-loading, only the current page loads; raising the counts later loads the
    /// neighbours, and lowering them again releases them.
    func testPreloadCountsCanChangeAfterTheOpen() async throws {
        let delegate = Delegate()
        let view = PaginationView(frame: CGRect(x: 0, y: 0, width: 300, height: 400), preloadPreviousPositionCount: 0, preloadNextPositionCount: 0, isScrollEnabled: true)
        view.delegate = delegate

        view.reloadAtIndex(1, location: .start, pageCount: 3, readingProgression: .ltr)
        for _ in 0 ..< 200 where delegate.updates.count < 2 {
            await Task.yield()
        }
        XCTAssertEqual(Set(view.loadedViews.keys), [1])

        view.setPreloadPositionCounts(previous: 1, next: 1)
        for _ in 0 ..< 200 where view.loadedViews.count < 3 {
            await Task.yield()
        }
        XCTAssertEqual(Set(view.loadedViews.keys), [0, 1, 2])
        XCTAssertEqual(view.currentIndex, 1, "Pre-loading moved the current page")

        view.setPreloadPositionCounts(previous: 0, next: 0)
        XCTAssertEqual(Set(view.loadedViews.keys), [1])
    }

    /// Lowering the counts while a neighbour is still loading drops the queued ones too, so no view
    /// loads outside the new range.
    func testLoweringTheCountsDropsTheQueuedNeighbours() async throws {
        let delegate = Delegate()
        delegate.held = [2]
        let view = PaginationView(frame: CGRect(x: 0, y: 0, width: 300, height: 400), preloadPreviousPositionCount: 0, preloadNextPositionCount: 3, isScrollEnabled: true)
        view.delegate = delegate

        view.reloadAtIndex(1, location: .start, pageCount: 8, readingProgression: .ltr)
        for _ in 0 ..< 200 where delegate.pages[2]?.release == nil {
            await Task.yield()
        }

        view.setPreloadPositionCounts(previous: 0, next: 0)
        delegate.pages[2]?.release?.resume()
        for _ in 0 ..< 200 {
            await Task.yield()
        }
        XCTAssertNil(delegate.pages[3], "A neighbour queued before the counts were lowered still loaded")
        XCTAssertNil(delegate.pages[4], "A neighbour queued before the counts were lowered still loaded")
        XCTAssertEqual(Set(view.loadedViews.keys), [1])
    }

    /// A jump loads its target before the neighbours still queued around the page it left.
    func testAJumpLoadsItsTargetBeforeTheOldNeighbours() async throws {
        let delegate = Delegate()
        delegate.held = [2]
        let view = PaginationView(frame: CGRect(x: 0, y: 0, width: 300, height: 400), preloadPreviousPositionCount: 0, preloadNextPositionCount: 3, isScrollEnabled: true)
        view.delegate = delegate

        view.reloadAtIndex(1, location: .start, pageCount: 10, readingProgression: .ltr)
        for _ in 0 ..< 200 where delegate.pages[2]?.release == nil {
            await Task.yield()
        }

        let jump = Task { await view.goToIndex(7, location: .start, options: NavigatorGoOptions(animated: false)) }
        for _ in 0 ..< 200 where delegate.pages[7] == nil {
            await Task.yield()
        }
        XCTAssertNotNil(delegate.pages[7], "The jump target didn't load while an old neighbour was still loading")
        XCTAssertNil(delegate.pages[3], "An old neighbour loaded before or instead of the jump target")
        XCTAssertNil(delegate.pages[4], "An old neighbour loaded before or instead of the jump target")

        delegate.pages[2]?.release?.resume()
        _ = await jump.value
        for _ in 0 ..< 200 {
            await Task.yield()
        }
        XCTAssertEqual(view.currentIndex, 7)
        XCTAssertEqual(Set(view.loadedViews.keys), [7, 8, 9])
        XCTAssertNil(delegate.pages[3])
    }
}
