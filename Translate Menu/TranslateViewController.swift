/*
* Copyright (c) 2015 Adrián Moreno Peña
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import Cocoa
import WebKit

class TranslateViewController: NSViewController, WKNavigationDelegate {
    @IBOutlet var webView: TranslateWebView!
    @IBOutlet var webViewContainer: NSView!
    @IBOutlet var progressIndicator: NSProgressIndicator!

    override var acceptsFirstResponder: Bool { false }

    var urlLoaded = false
    let defaultUrl = "https://translate.google.com?text="

    private var focusRetryCount = 0
    private let maxFocusRetryCount = 10
    private var pendingFocusWorkItem: DispatchWorkItem?

    override func viewWillAppear() {
        super.viewWillAppear()

        NSLog("TranslateViewController: willAppear")
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)

        if !urlLoaded {
            NSLog("TranslateViewController: loadURL")
            urlLoaded = true
            webView.navigationDelegate = self
            webView.load(URLRequest(url: URL(string: defaultUrl)!))
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        focusRetryCount = 0
        focusInput()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        pendingFocusWorkItem?.cancel()
        pendingFocusWorkItem = nil
        focusRetryCount = 0
    }

    deinit {
        pendingFocusWorkItem?.cancel()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("TranslateViewController: URL did finish")
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true

        focusRetryCount = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.focusInput()
        }
    }

    public func loadText(text: String) {
        NSLog("TranslateViewController: loading text: " + text)

        guard webView != nil else { return }

        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        webView.load(getTranslateURL(textToTranslate: text))
    }

    public func getTranslateURL(textToTranslate: String) -> URLRequest {
        var allowedQueryParamAndKey = CharacterSet.urlQueryAllowed
        allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
        let sanitizedInput = textToTranslate.addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey) ?? textToTranslate

        let urlString = "\(defaultUrl)\(sanitizedInput)"
        let url = URL(string: urlString) ?? URL(string: defaultUrl)!
        return URLRequest(url: url)
    }

    public func focusInput() {
        guard isViewLoaded else { return }

        pendingFocusWorkItem?.cancel()
        pendingFocusWorkItem = nil

        guard view.superview != nil || view.window != nil else {
            NSLog("TranslateViewController: focusInput aborted, view is not in active hierarchy")
            return
        }

        guard let window = view.window else {
            guard focusRetryCount < maxFocusRetryCount else {
                NSLog("TranslateViewController: focusInput retry limit reached")
                return
            }

            focusRetryCount += 1

            let workItem = DispatchWorkItem { [weak self] in
                self?.focusInput()
            }

            pendingFocusWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
            return
        }

        focusRetryCount = 0

        window.level = .normal
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.focusWebInputElement()
        }
    }

    private func focusWebInputElement() {
        let javascript = """
        (function() {
            const selectors = [
                'textarea',
                'input[type="text"]',
                '[contenteditable="true"]',
                'div[contenteditable="true"]',
                'textarea[aria-label]',
                'c-wiz textarea'
            ];

            for (const selector of selectors) {
                const el = document.querySelector(selector);
                if (el) {
                    el.focus();
                    if (typeof el.click === 'function') {
                        el.click();
                    }
                    return 'focused';
                }
            }

            return 'not_found';
        })();
        """

        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                NSLog("TranslateViewController: focusWebInputElement error: \(error.localizedDescription)")
            } else {
                NSLog("TranslateViewController: focusWebInputElement result: \(String(describing: result))")
            }
        }
    }

    public override func keyDown(with event: NSEvent) {
        NSLog("TranslateViewController keyDown: " + (event.characters ?? ""))
        super.keyDown(with: event)
    }
}
