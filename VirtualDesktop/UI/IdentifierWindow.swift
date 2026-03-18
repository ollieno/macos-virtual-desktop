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
            .frame(width: 700, height: 200)
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

    init(screen: NSScreen) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
    }

    func update(name: String, color: Color, on screen: NSScreen) {
        let view = IdentifierView(name: name, color: color)
        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.translatesAutoresizingMaskIntoConstraints = false
            contentView = hv
            hostingView = hv
        }

        let size = NSSize(width: 700, height: 200)
        setContentSize(size)

        let screenFrame = screen.frame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.midY - size.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))

        orderFrontRegardless()
    }
}

// MARK: - Identifier controller (manages one panel per screen)

final class IdentifierController {
    private var panels: [IdentifierPanel] = []

    func hide() {
        for panel in panels {
            panel.orderOut(nil)
        }
    }

    func update(name: String, index: Int) {
        let screens = NSScreen.screens
        let color = DesktopColors.color(forIndex: index)

        while panels.count < screens.count {
            panels.append(IdentifierPanel(screen: screens[panels.count]))
        }

        for (i, screen) in screens.enumerated() {
            panels[i].update(name: name, color: color, on: screen)
        }

        for i in screens.count..<panels.count {
            panels[i].orderOut(nil)
        }
    }
}
