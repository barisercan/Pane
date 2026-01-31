//
//  WindowInfo.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import AppKit
import ApplicationServices

struct WindowInfo: Identifiable {
    let id: UUID
    let windowId: CGWindowID
    let title: String
    let appName: String
    let appIcon: NSImage?
    let pid: pid_t
    let axElement: AXUIElement
    let isMinimized: Bool
    let screenIndex: Int
    let frame: CGRect
}
