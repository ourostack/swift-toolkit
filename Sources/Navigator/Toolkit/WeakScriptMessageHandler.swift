//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import WebKit

/// Forwards script messages to `target` without retaining it.
///
/// `WKUserContentController` retains its script message handlers. A view
/// that owns a web view and registers itself as a handler therefore forms a
/// cycle (view → web view → configuration → user content controller → view),
/// which kept every spread view, its web view and its web content process
/// alive when the view hierarchy above the `PaginationView` was removed.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
