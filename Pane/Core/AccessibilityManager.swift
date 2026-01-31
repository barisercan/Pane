//
//  AccessibilityManager.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import AppKit
import ApplicationServices

final class AccessibilityManager {
    static let shared = AccessibilityManager()

    private init() {}

    /// Check if the app has accessibility permissions
    func checkAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permissions
    func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Check and prompt if needed, returns current status
    func ensureAccessibility() -> Bool {
        if checkAccessibility() {
            return true
        }
        promptForAccessibility()
        return false
    }
}
