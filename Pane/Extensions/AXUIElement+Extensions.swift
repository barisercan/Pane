//
//  AXUIElement+Extensions.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import ApplicationServices
import CoreGraphics

extension AXUIElement {
    var title: String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &value)
        guard status == .success, let title = value as? String else { return nil }
        return title
    }

    var isMinimized: Bool {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(self, kAXMinimizedAttribute as CFString, &value)
        guard status == .success, let minimized = value as? Bool else { return false }
        return minimized
    }

    var position: CGPoint {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(self, kAXPositionAttribute as CFString, &value)
        guard status == .success, let axValue = value else { return .zero }

        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    var size: CGSize {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(self, kAXSizeAttribute as CFString, &value)
        guard status == .success, let axValue = value else { return .zero }

        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    var windows: [AXUIElement]? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(self, kAXWindowsAttribute as CFString, &value)
        guard status == .success, let windows = value as? [AXUIElement] else { return nil }
        return windows
    }

    var focusedWindow: AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(self, kAXFocusedWindowAttribute as CFString, &value)
        guard status == .success else { return nil }
        return (value as! AXUIElement)
    }
}
