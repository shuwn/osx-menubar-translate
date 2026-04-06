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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var statusMenu: NSMenu!

    var statusItem: NSStatusItem!
    let popover = NSPopover()
    let translateViewController = TranslateViewController(nibName: "TranslateViewController", bundle: nil)
    var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("MenuTranslate: starting")

        statusItem = NSStatusBar.system.statusItem(withLength: 32)

        let image = NSImage(named: "TranslateStatusBarButtonImage")
        image?.isTemplate = true

        if let button = statusItem.button {
            button.image = image
            button.action = #selector(statusItemButtonActivated(sender:))
            button.sendAction(on: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp])
        }

        popover.contentViewController = translateViewController
        popover.behavior = .applicationDefined

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [unowned self] event in
            guard self.popover.isShown else { return }

            if let clickedWindow = event?.window,
               let popoverWindow = self.popover.contentViewController?.view.window,
               clickedWindow == popoverWindow {
                return
            }

            self.closePopover(sender: event)
        }

        NSApplication.shared.servicesProvider = self
        NSLog("MenuTranslate: started")
    }

    @IBAction
    func statusItemButtonActivated(sender: AnyObject?) {
        let buttonMask = NSEvent.pressedMouseButtons
        var primaryDown = ((buttonMask & (1 << 0)) != 0)
        var secondaryDown = ((buttonMask & (1 << 1)) != 0)

        if primaryDown && (NSEvent.modifierFlags == .control) {
            primaryDown = false
            secondaryDown = true
        }

        if primaryDown {
            if popover.isShown {
                closePopover(sender: sender)
            } else {
                showPopover(sender: sender)
            }
        } else if secondaryDown {
            statusItem.menu = self.statusMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    func showPopover(sender: AnyObject?, keyword: String? = nil) {
        guard let button = statusItem.button else { return }

        NSApp.activate(ignoringOtherApps: true)

        popover.behavior = .applicationDefined
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        DispatchQueue.main.async {
            guard let window = self.popover.contentViewController?.view.window else { return }

            window.level = .normal
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            self.translateViewController.focusInputIfPossible()
        }

        eventMonitor?.start()
    }

    func closePopover(sender: AnyObject?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }

    @objc
    func translateService(_ pasteboard: NSPasteboard,
                          userData: String,
                          error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string) else { return }

        NSLog("MenuTranslate: handling service invocation: " + text)
        translateViewController.loadText(text: text)
        showPopover(sender: nil, keyword: text)
    }

    @IBAction
    func quitApp(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }

    @IBAction
    func aboutMenuActivated(sender: AnyObject?) {
        NSLog("MenuTranslate: opening github site")
        NSWorkspace.shared.open(URL(string: "https://github.com/zetxek/osx-menubar-translate")!)
    }
}
