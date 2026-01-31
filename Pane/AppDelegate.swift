//
//  AppDelegate.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController?
    private var hotkeyManager: HotkeyManager?
    private var windowManager: WindowManager?
    private var clickOutsideMonitor: Any?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar icon
        setupStatusItem()

        // Check accessibility permissions
        if !AccessibilityManager.shared.checkAccessibility() {
            // Show alert explaining why we need accessibility
            showAccessibilityAlert()
        }

        // Initialize managers
        windowManager = WindowManager()
        panelController = PanelController(windowManager: windowManager!)

        // Setup hotkey manager with toggle callback
        hotkeyManager = HotkeyManager { [weak self] in
            self?.togglePanel()
        }
        hotkeyManager?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
        removeClickOutsideMonitor()
    }

    // MARK: - Status Item (Menu Bar Icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Pane")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Window Switcher", action: #selector(showPanelFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let accessibilityItem = NSMenuItem(title: "Accessibility Status...", action: #selector(checkAccessibilityStatus), keyEquivalent: "")
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Pane", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showPanelFromMenu() {
        showPanel()
    }

    @objc private func checkAccessibilityStatus() {
        if AccessibilityManager.shared.checkAccessibility() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Enabled"
            alert.informativeText = "Pane has accessibility access. Double-tap ⌘ to open the window switcher."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Pane needs accessibility access to detect the ⌘ double-tap hotkey and list windows.\n\nClick 'Open Settings' to grant access, then restart Pane."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AccessibilityManager.shared.promptForAccessibility()
        }
    }

    // MARK: - Panel Management

    private func togglePanel() {
        guard let panel = panelController else { return }

        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel = panelController, let windowManager = windowManager else { return }

        // Refresh window list
        windowManager.refreshWindows()

        // Show the panel
        panel.show()

        // Add click-outside monitor
        addClickOutsideMonitor()
    }

    private func hidePanel() {
        panelController?.hide()
        removeClickOutsideMonitor()
    }

    private func addClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let panel = self?.panelController, panel.isVisible else { return }

            // Check if click is outside the panel
            if let panelFrame = panel.panel?.frame {
                let screenPoint = NSEvent.mouseLocation
                if !panelFrame.contains(screenPoint) {
                    self?.hidePanel()
                }
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
}
