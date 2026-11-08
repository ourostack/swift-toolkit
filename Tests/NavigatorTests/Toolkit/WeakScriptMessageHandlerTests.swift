//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import WebKit
import XCTest

@MainActor
class WeakScriptMessageHandlerTests: XCTestCase {
    private final class Handler: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
    }

    /// A user content controller holding the proxy does not keep the handler alive.
    func testTheUserContentControllerDoesNotRetainTheHandler() {
        let controller = WKUserContentController()
        weak var weakHandler: Handler?
        autoreleasepool {
            let handler = Handler()
            weakHandler = handler
            controller.add(WeakScriptMessageHandler(handler), name: "test")
        }
        XCTAssertNil(weakHandler)
        controller.removeScriptMessageHandler(forName: "test")
    }

    /// The cycle the proxy replaces: added directly, the handler stays alive.
    func testAHandlerAddedDirectlyIsRetained() {
        let controller = WKUserContentController()
        weak var weakHandler: Handler?
        autoreleasepool {
            let handler = Handler()
            weakHandler = handler
            controller.add(handler, name: "test")
        }
        XCTAssertNotNil(weakHandler)
        controller.removeScriptMessageHandler(forName: "test")
    }
}
