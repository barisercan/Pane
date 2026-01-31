//
//  ScreenBadge.swift
//  Pane
//
//  Created by Baha Baris Ercan on 31.01.2026.
//

import SwiftUI

struct ScreenBadge: View {
    let screenIndex: Int

    private var badgeCharacter: String {
        // Use circled numbers: ①②③④⑤
        let circledNumbers = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]
        if screenIndex < circledNumbers.count {
            return circledNumbers[screenIndex]
        }
        return "\(screenIndex + 1)"
    }

    var body: some View {
        Text(badgeCharacter)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
    }
}

#Preview {
    HStack(spacing: 10) {
        ScreenBadge(screenIndex: 0)
        ScreenBadge(screenIndex: 1)
        ScreenBadge(screenIndex: 2)
    }
    .padding()
    .background(Color.black)
}
