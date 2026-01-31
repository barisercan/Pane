//
//  PanelController.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import AppKit
import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.ercanbaris.Pane", category: "PanelController")

// Custom panel that can become key
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// Observable state for the panel
final class PanelState: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedIndex: Int = 0

    func reset() {
        searchText = ""
        selectedIndex = 0
    }
}

final class PanelController {
    private(set) var panel: NSPanel?
    private let windowManager: WindowManager
    let panelState = PanelState()
    private var keyMonitor: Any?
    private var hostingView: NSHostingView<AnyView>?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        setupPanel()
    }

    private func setupPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        // Create visual effect view for vibrancy
        let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        // Create SwiftUI content - use the panelState directly
        let contentView = WindowListView(
            windowManager: windowManager,
            panelState: panelState,
            onSelect: { [weak self] window in
                self?.windowManager.focusWindow(window)
                self?.hide()
            },
            onMoveWindow: { [weak self] window, screenIndex in
                self?.windowManager.moveWindow(window, toScreen: screenIndex)
            }
        )

        let hosting = NSHostingView(rootView: AnyView(contentView))
        hosting.translatesAutoresizingMaskIntoConstraints = false

        visualEffect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
        ])

        panel.contentView = visualEffect
        self.panel = panel
        self.hostingView = hosting
    }

    func show() {
        guard let panel = panel else { return }

        logger.info("Showing panel")

        // Reset state
        panelState.reset()

        // Get the screen where the mouse cursor is
        let mouseLocation = NSEvent.mouseLocation
        var targetScreen = NSScreen.main ?? NSScreen.screens.first!

        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                targetScreen = screen
                break
            }
        }

        // Position at top-left of target screen with margin
        let screenFrame = targetScreen.visibleFrame
        let margin: CGFloat = 20
        let panelX = screenFrame.origin.x + margin
        let panelY = screenFrame.origin.y + screenFrame.height - panel.frame.height - margin
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))

        logger.info("Panel position: \(panelX), \(panelY) on screen \(NSScreen.screens.firstIndex(of: targetScreen) ?? -1)")

        // Activate and show
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Setup keyboard monitor after panel is shown
        setupKeyMonitor()
    }

    func hide() {
        logger.info("Hiding panel")
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    private var globalKeyMonitor: Any?

    private func setupKeyMonitor() {
        removeKeyMonitor()

        logger.info("Setting up key monitors")

        // Use GLOBAL monitor to intercept keys before SwiftUI
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            _ = self.handleKeyEvent(event)
        }

        // Local monitor for when our app is active
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if self.handleKeyEvent(event) {
                return nil // consume the event
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        logger.info("Removed key monitors")
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check for Option+number (1-9) first
        if modifiers.contains(.option) {
            if let chars = event.charactersIgnoringModifiers,
               let num = Int(chars), num >= 1 && num <= 9 {
                moveCurrentWindowToScreen(num - 1)
                return true
            }
        }

        // Ignore events with Command modifier (let system handle Cmd+C, etc)
        if modifiers.contains(.command) {
            return false
        }

        switch keyCode {
        case 126: // Up arrow
            moveSelection(by: -1)
            return true

        case 125: // Down arrow
            moveSelection(by: 1)
            return true

        case 36: // Return
            selectCurrentWindow()
            return true

        case 53: // Escape
            if !panelState.searchText.isEmpty {
                panelState.searchText = ""
                panelState.selectedIndex = 0
            } else {
                hide()
            }
            return true

        case 51: // Backspace
            if !panelState.searchText.isEmpty {
                panelState.searchText.removeLast()
                panelState.selectedIndex = 0
            }
            return true

        default:
            // Handle typing for search
            if let chars = event.characters, !chars.isEmpty {
                let char = chars.first!
                if char.isLetter || char.isNumber || char == " " {
                    panelState.searchText.append(char)
                    panelState.selectedIndex = 0
                    return true
                }
            }
            return false
        }
    }

    private func moveSelection(by offset: Int) {
        let filteredCount = windowManager.filteredWindows(searchText: panelState.searchText).count
        let currentIndex = panelState.selectedIndex
        let newIndex = currentIndex + offset

        if newIndex >= 0 && newIndex < filteredCount {
            panelState.selectedIndex = newIndex
        }
    }

    private func selectCurrentWindow() {
        let windows = windowManager.filteredWindows(searchText: panelState.searchText)
        guard panelState.selectedIndex < windows.count else { return }
        let window = windows[panelState.selectedIndex]
        logger.info("Selecting window: \(window.title)")
        windowManager.focusWindow(window)
        hide()
    }

    private func moveCurrentWindowToScreen(_ screenIndex: Int) {
        let screens = NSScreen.screens
        guard screenIndex < screens.count else { return }

        let windows = windowManager.filteredWindows(searchText: panelState.searchText)
        guard panelState.selectedIndex < windows.count else { return }

        let window = windows[panelState.selectedIndex]
        logger.info("Moving window to screen \(screenIndex)")
        windowManager.moveWindow(window, toScreen: screenIndex)

        // Re-activate and re-setup key monitor after moving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let panel = self.panel else { return }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            self.setupKeyMonitor()
            logger.info("Re-setup key monitor after move")
        }
    }

    deinit {
        removeKeyMonitor()
    }
}
