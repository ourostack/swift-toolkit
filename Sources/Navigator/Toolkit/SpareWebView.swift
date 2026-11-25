//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import WebKit

/// Keeps one web view made ahead of need, its page process already started and
/// through a first load, for the next spread view to take.
///
/// WebKit starts a new page process for every new web view, and keeps none for
/// reuse (its process cache is off while process swap on navigation is). A
/// spread made for a far jump otherwise waits on a cold process: on a loaded
/// device, seconds pass before its chapter is even asked of the server.
///
/// Only a spare whose first load has finished is handed out, so its warm-up
/// navigation never reaches the spread view's navigation delegate. Taking one
/// (or finding none ready) starts the next. The spare belongs to one
/// navigator: its configuration carries that navigator's scheme handler.
@MainActor
final class SpareWebView<View: AnyObject> {
    typealias Make = () -> View
    typealias Warm = (View, @escaping () -> Void) -> AnyObject?

    private let make: Make
    private let warm: Warm
    private var spare: View?
    private var isReady = false
    private var isClosed = false
    /// Whatever the warm-up needs kept alive until it ends (a web view holds its navigation delegate weakly).
    private var warming: AnyObject?

    /// - Parameters:
    ///   - make: Makes a web view configured as a spread view's.
    ///   - warm: Starts the web view's first load and calls back once it has
    ///     finished.
    init(make: @escaping Make, warm: @escaping Warm) {
        self.make = make
        self.warm = warm
    }

    /// The spare, if its warm-up load has finished. Either way, a new spare is
    /// started for the next spread.
    func take() -> View? {
        guard !isClosed else { return nil }
        let taken = isReady ? spare : nil
        if taken != nil {
            spare = nil
            isReady = false
        }
        prepare()
        return taken
    }

    /// Drops the spare and makes no more, when the navigator goes.
    func close() {
        isClosed = true
        spare = nil
        warming = nil
        isReady = false
    }

    private func prepare() {
        guard !isClosed, spare == nil else { return }
        let view = make()
        spare = view
        warming = warm(view) { [weak self, weak view] in
            guard let self, let view, self.spare === view else { return }
            self.isReady = true
            self.warming = nil
        }
    }
}

/// Calls back once a warm-up load ends, however it ends.
final class SpareWarmUp: NSObject, WKNavigationDelegate {
    private var done: (() -> Void)?

    init(_ done: @escaping () -> Void) {
        self.done = done
    }

    private func finish(_ webView: WKWebView) {
        if webView.navigationDelegate === self { webView.navigationDelegate = nil }
        done?()
        done = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(webView)
    }
}
