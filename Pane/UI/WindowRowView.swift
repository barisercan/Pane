//
//  WindowRowView.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import SwiftUI

struct WindowRowView: View {
    let window: WindowInfo
    let isSelected: Bool
    let showScreenBadge: Bool

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }

            // Window info
            VStack(alignment: .leading, spacing: 2) {
                Text(window.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(window.isMinimized ? .secondary : .primary)

                Text(window.appName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Screen badge (if multiple screens)
            if showScreenBadge {
                ScreenBadge(screenIndex: window.screenIndex)
            }

            // Minimized indicator
            if window.isMinimized {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
        )
        .contentShape(Rectangle())
        .opacity(window.isMinimized ? 0.6 : 1.0)
    }
}
