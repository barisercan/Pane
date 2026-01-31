//
//  WindowListView.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import SwiftUI

struct WindowListView: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var panelState: PanelState

    let onSelect: (WindowInfo) -> Void
    let onMoveWindow: (WindowInfo, Int) -> Void

    private var filteredWindows: [WindowInfo] {
        windowManager.filteredWindows(searchText: panelState.searchText)
    }

    private var hasMultipleScreens: Bool {
        NSScreen.screens.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field (display only - input handled by key monitor)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                if panelState.searchText.isEmpty {
                    Text("Type to search...")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                } else {
                    Text(panelState.searchText)
                        .font(.system(size: 14))
                }

                Spacer()

                if !panelState.searchText.isEmpty {
                    Text("⌫ clear")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.2))

            Divider()
                .background(Color.white.opacity(0.1))

            // Window list
            if filteredWindows.isEmpty {
                Spacer()
                Text(panelState.searchText.isEmpty ? "No windows" : "No matches for '\(panelState.searchText)'")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredWindows.enumerated()), id: \.element.id) { index, window in
                                WindowRowView(
                                    window: window,
                                    isSelected: index == panelState.selectedIndex,
                                    showScreenBadge: hasMultipleScreens
                                )
                                .id(index)
                                .onTapGesture {
                                    onSelect(window)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: panelState.selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            // Keyboard shortcuts hint
            Divider()
                .background(Color.white.opacity(0.1))
            HStack {
                Text("↑↓ navigate")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if hasMultipleScreens {
                    Text("⌥1-3 move to screen")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 360)
    }
}
