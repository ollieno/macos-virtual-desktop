import Cocoa
import SwiftUI

// MARK: - SwiftUI view

private struct BorderView: View {
    let color: Color
    let lineWidth: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(color, lineWidth: lineWidth)
            .ignoresSafeArea()
    }
}

// MARK: - Single border panel

private final class BorderPanel: NSPanel {
    private var hostingView: NSHostingView<BorderView>?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
    }

    func update(color: Color, on screen: NSScreen) {
        setFrame(screen.frame, display: false)

        let view = BorderView(color: color)
        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.autoresizingMask = [.width, .height]
            hv.frame = contentView?.bounds ?? NSRect(origin: .zero, size: frame.size)
            contentView?.addSubview(hv)
            hostingView = hv
        }

        orderFrontRegardless()
    }
}

// MARK: - Border controller (manages one panel per screen)

final class BorderController {
    private var panels: [BorderPanel] = []

    func hide() {
        for panel in panels {
            panel.orderOut(nil)
        }
    }

    func update(index: Int) {
        let screens = NSScreen.screens
        let color = DesktopColors.color(forIndex: index)

        // Ensure we have enough panels
        while panels.count < screens.count {
            panels.append(BorderPanel(screen: screens[panels.count]))
        }

        // Update each screen
        for (i, screen) in screens.enumerated() {
            panels[i].update(color: color, on: screen)
        }

        // Hide extra panels if screens were disconnected
        for i in screens.count..<panels.count {
            panels[i].orderOut(nil)
        }
    }
}
