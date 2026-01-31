//
//  HotkeyManager.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import AppKit
import Carbon

final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onDoubleTap: () -> Void

    // Double-tap detection state
    private var lastCmdUpTime: TimeInterval = 0
    private var tapCount: Int = 0
    private var cmdIsDown: Bool = false
    private var otherKeyPressed: Bool = false
    private var lastCmdDownTime: TimeInterval = 0

    // Timing thresholds (in seconds)
    private let maxTapGap: TimeInterval = 0.4       // Max time between tap1 UP and tap2 DOWN
    private let maxHoldDuration: TimeInterval = 0.5 // Max time Cmd can be held per tap

    init(onDoubleTap: @escaping () -> Void) {
        self.onDoubleTap = onDoubleTap
    }

    func start() {
        // Create event tap for flagsChanged and keyDown events
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[Pane] Failed to create event tap - accessibility permission required")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[Pane] Event tap started successfully")
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let now = Date().timeIntervalSince1970

        // Handle tap disabled (re-enable it)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // Handle key down events - reset state if other keys pressed while Cmd held
        if type == .keyDown && cmdIsDown {
            otherKeyPressed = true
            resetState()
            return Unmanaged.passRetained(event)
        }

        // Handle flags changed (modifier keys)
        if type == .flagsChanged {
            let flags = event.flags
            let cmdPressed = flags.contains(.maskCommand)

            // Check for other modifiers - reset if any are pressed
            let otherModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate]
            if !flags.intersection(otherModifiers).isEmpty {
                resetState()
                return Unmanaged.passRetained(event)
            }

            if cmdPressed && !cmdIsDown {
                // Cmd key pressed down
                cmdIsDown = true
                otherKeyPressed = false
                lastCmdDownTime = now

                // Check if this is the second tap (pressed within maxTapGap of last release)
                if tapCount == 1 {
                    let gapSinceLastTap = now - lastCmdUpTime
                    if gapSinceLastTap > maxTapGap {
                        // Too slow - reset and treat as first tap
                        tapCount = 0
                    }
                }

            } else if !cmdPressed && cmdIsDown {
                // Cmd key released
                cmdIsDown = false
                let holdDuration = now - lastCmdDownTime

                // Check if it was a quick tap (not a long hold)
                if holdDuration < maxHoldDuration && !otherKeyPressed {
                    if tapCount == 1 {
                        // This is the second tap release - check timing
                        let gapSinceLastTap = now - lastCmdUpTime
                        if gapSinceLastTap < (maxTapGap + maxHoldDuration) {
                            // Double-tap detected!
                            print("[Pane] Double-tap detected!")
                            DispatchQueue.main.async {
                                self.onDoubleTap()
                            }
                            resetState()
                        } else {
                            // Too slow, start over
                            tapCount = 1
                            lastCmdUpTime = now
                        }
                    } else {
                        // First tap completed
                        tapCount = 1
                        lastCmdUpTime = now
                    }
                } else {
                    // Long hold or other key pressed - reset
                    resetState()
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func resetState() {
        tapCount = 0
        otherKeyPressed = false
    }
}
