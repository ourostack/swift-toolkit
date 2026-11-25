//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Stub: never makes or hands out a spare web view. A new spread view always
/// starts a cold page process.
@MainActor
final class SpareWebView<View: AnyObject> {
    typealias Make = () -> View
    typealias Warm = (View, @escaping () -> Void) -> AnyObject?

    init(make: @escaping Make, warm: @escaping Warm) {}

    func take() -> View? { nil }

    func close() {}
}
