import Cocoa
import SwiftUI

// MARK: - SwiftUI view

private struct IdentifierView: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.system(size: 48, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(minWidth: 700, minHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 15/255, green: 15/255, blue: 20/255).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

// MARK: - Single identifier panel

private final class IdentifierPanel: NSPanel {
    private var hostingView: NSHostingView<IdentifierView>?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .normal
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
    }

    func show(name: String, color: Color, on screen: NSScreen) {
        let view = IdentifierView(name: name, color: color)
        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.translatesAutoresizingMaskIntoConstraints = false
            contentView = hv
            hostingView = hv
        }

        let size = hostingView?.fittingSize ?? NSSize(width: 700, height: 200)
        setContentSize(size)

        let screenFrame = screen.frame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.midY - size.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))

        orderBack(nil)
    }
}

// MARK: - Identifier controller (one panel per desktop per screen)

final class IdentifierController {
    // Panels keyed by spaceUUID, each containing one panel per screen
    private var panelsPerSpace: [String: [IdentifierPanel]] = [:]

    func hide() {
        for (_, panels) in panelsPerSpace {
            for panel in panels {
                panel.orderOut(nil)
            }
        }
    }

    func update(name: String, index: Int, spaceUUID: String) {
        let screens = NSScreen.screens
        let color = DesktopColors.color(forIndex: index)

        // Get or create panels for this specific desktop
        var panels = panelsPerSpace[spaceUUID] ?? []

        // Ensure we have enough panels for all screens
        while panels.count < screens.count {
            panels.append(IdentifierPanel())
        }

        // Show on each screen
        for (i, screen) in screens.enumerated() {
            panels[i].show(name: name, color: color, on: screen)
        }

        // Hide extra panels if screens were disconnected
        for i in screens.count..<panels.count {
            panels[i].orderOut(nil)
        }

        panelsPerSpace[spaceUUID] = panels
    }
}
