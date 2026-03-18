import Cocoa
import SwiftUI

// MARK: - SwiftUI view

private struct OverlayView: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(minWidth: 120, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.75))
            )
    }
}

// MARK: - Single overlay panel

private final class OverlayPanel: NSPanel {
    private var hostingView: NSHostingView<OverlayView>?

    init(screen: NSScreen) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alphaValue = 0
    }

    func show(name: String, on screen: NSScreen) {
        let view = OverlayView(name: name)
        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.translatesAutoresizingMaskIntoConstraints = false
            contentView = hv
            hostingView = hv
        }

        let fittingSize = hostingView?.fittingSize ?? CGSize(width: 200, height: 80)
        setContentSize(fittingSize)

        // Center on the given screen
        let screenFrame = screen.frame
        let x = screenFrame.midX - fittingSize.width / 2
        let y = screenFrame.midY - fittingSize.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0
            animator().alphaValue = 1
        }
        orderFrontRegardless()
    }

    func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }
    }
}

// MARK: - Overlay controller (manages one panel per screen)

final class OverlayController {
    private var panels: [OverlayPanel] = []
    private var fadeTimer: Timer?
    private var showTimer: Timer?

    func show(name: String) {
        // Cancel any pending show/fade
        showTimer?.invalidate()
        fadeTimer?.invalidate()

        // Small delay so Mission Control animation finishes first
        showTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.showImmediately(name: name)
        }
    }

    private func showImmediately(name: String) {
        let screens = NSScreen.screens

        // Ensure we have enough panels (reuse existing, create new if needed)
        while panels.count < screens.count {
            panels.append(OverlayPanel(screen: screens[panels.count]))
        }

        // Show on each screen
        for (i, screen) in screens.enumerated() {
            panels[i].show(name: name, on: screen)
        }

        // Hide any extra panels (if screens were disconnected)
        for i in screens.count..<panels.count {
            panels[i].fadeOut()
        }

        // Schedule fade-out after 1.5s
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.fadeOutAll()
        }
    }

    private func fadeOutAll() {
        for panel in panels {
            panel.fadeOut()
        }
    }
}
