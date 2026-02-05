//
//  WindowManager.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import AppKit
import ApplicationServices
import Combine
import os.log

private let logger = Logger(subsystem: "com.ercanbaris.Pane", category: "WindowManager")

@MainActor
final class WindowManager: ObservableObject {
    @Published var windows: [WindowInfo] = []

    private var windowFocusOrder: [WindowIdentifier] = []

    nonisolated init() {}

    struct WindowIdentifier: Hashable, Sendable {
        let pid: pid_t
        let windowId: CGWindowID
    }

    func refreshWindows() {
        var allWindows: [WindowInfo] = []

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        logger.info("Found \(runningApps.count) running apps")

        for app in runningApps {
            let appWindows = getWindowsForApp(app)
            allWindows.append(contentsOf: appWindows)
        }

        // Sort: non-minimized first, then by focus order, minimized at bottom
        allWindows.sort { w1, w2 in
            if w1.isMinimized != w2.isMinimized {
                return !w1.isMinimized
            }

            let index1 = windowFocusOrder.firstIndex(of: WindowIdentifier(pid: w1.pid, windowId: w1.windowId)) ?? Int.max
            let index2 = windowFocusOrder.firstIndex(of: WindowIdentifier(pid: w2.pid, windowId: w2.windowId)) ?? Int.max
            return index1 < index2
        }

        logger.info("Total windows: \(allWindows.count)")
        for w in allWindows {
            logger.info("  - '\(w.appName)' : '\(w.title)'")
        }

        windows = allWindows
    }

    private func getWindowsForApp(_ app: NSRunningApplication) -> [WindowInfo] {
        var result: [WindowInfo] = []

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)

        if status != .success {
            logger.debug("Could not get windows for \(app.localizedName ?? "unknown"): \(status.rawValue)")
            return result
        }

        guard let axWindows = windowsRef as? [AXUIElement] else {
            return result
        }

        logger.debug("\(app.localizedName ?? "unknown") has \(axWindows.count) AX windows")

        for axWindow in axWindows {
            let title = axWindow.title ?? ""
            let displayTitle = title.isEmpty ? (app.localizedName ?? "Untitled") : title

            let isMinimized = axWindow.isMinimized
            let position = axWindow.position
            let size = axWindow.size

            // Get window ID directly from AXUIElement
            let windowId: CGWindowID = axWindow.cgWindowID ?? 0

            let screenIndex = getScreenIndex(for: position)

            let windowInfo = WindowInfo(
                id: UUID(),
                windowId: windowId,
                title: displayTitle,
                appName: app.localizedName ?? "Unknown",
                appIcon: app.icon,
                pid: app.processIdentifier,
                axElement: axWindow,
                isMinimized: isMinimized,
                screenIndex: screenIndex,
                frame: CGRect(origin: position, size: size)
            )

            result.append(windowInfo)

            // Track in focus order if not already tracked
            let identifier = WindowIdentifier(pid: app.processIdentifier, windowId: windowId)
            if !windowFocusOrder.contains(identifier) {
                windowFocusOrder.append(identifier)
            }
        }

        return result
    }

    private func getScreenIndex(for position: CGPoint) -> Int {
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            if screen.frame.contains(position) {
                return index
            }
        }
        return 0
    }

    func focusWindow(_ window: WindowInfo) {
        // Raise the window
        AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)

        // Activate the application
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        // Unminimize if needed
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.axElement, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }

        // Update focus order
        let identifier = WindowIdentifier(pid: window.pid, windowId: window.windowId)
        windowFocusOrder.removeAll { $0 == identifier }
        windowFocusOrder.insert(identifier, at: 0)
    }

    func moveWindow(_ window: WindowInfo, toScreen screenIndex: Int) {
        let screens = NSScreen.screens
        guard screenIndex < screens.count else { return }

        let targetScreen = screens[screenIndex]
        let targetFrame = targetScreen.visibleFrame

        // Get current window size
        let windowSize = window.frame.size

        // Center window on target screen
        let newX = targetFrame.origin.x + (targetFrame.width - windowSize.width) / 2
        let newY = targetFrame.origin.y + (targetFrame.height - windowSize.height) / 2

        let newPosition = CGPoint(x: newX, y: newY)

        // Move the window
        var position = newPosition
        let positionValue = AXValueCreate(.cgPoint, &position)!
        AXUIElementSetAttributeValue(window.axElement, kAXPositionAttribute as CFString, positionValue)

        // Refresh to update screen badges
        refreshWindows()
    }

    func filteredWindows(searchText: String) -> [WindowInfo] {
        guard !searchText.isEmpty else { return windows }

        let lowercasedSearch = searchText.lowercased()
        let filtered = windows.filter { window in
            let titleMatch = window.title.lowercased().contains(lowercasedSearch)
            let appMatch = window.appName.lowercased().contains(lowercasedSearch)
            return titleMatch || appMatch
        }

        // Debug: log all windows and which ones match
        logger.info("Search '\(searchText)' in \(self.windows.count) windows -> \(filtered.count) results")
        for window in windows {
            let titleMatch = window.title.lowercased().contains(lowercasedSearch)
            let appMatch = window.appName.lowercased().contains(lowercasedSearch)
            if titleMatch || appMatch {
                logger.debug("  MATCH: '\(window.appName)' / '\(window.title)'")
            }
        }

        return filtered
    }
}
