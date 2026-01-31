//
//  PaneApp.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import SwiftUI

@main
struct PaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
