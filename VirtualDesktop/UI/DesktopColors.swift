import SwiftUI

enum DesktopColors {
    static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .red, .cyan, .yellow, .mint, .indigo
    ]

    static func color(forIndex index: Int) -> Color {
        palette[index % palette.count]
    }
}
