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

// MARK: - Overlay window

final class OverlayWindow: NSPanel {
    private var hostingView: NSHostingView<OverlayView>?
    private var fadeTimer: Timer?

    init() {
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

    // MARK: - Public API

    func show(name: String) {
        // Cancel any in-progress fade
        fadeTimer?.invalidate()
        fadeTimer = nil

        // Update or create the hosted view
        let view = OverlayView(name: name)
        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.translatesAutoresizingMaskIntoConstraints = false
            contentView = hv
            hostingView = hv
        }

        // Size the window to fit content
        let fittingSize = hostingView?.fittingSize ?? CGSize(width: 200, height: 80)
        setContentSize(fittingSize)

        // Center on main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - fittingSize.width / 2
            let y = screenFrame.midY - fittingSize.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show immediately at full opacity
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0
            animator().alphaValue = 1
        }
        orderFrontRegardless()

        // Schedule fade-out after 1.5 s
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }

    // MARK: - Private

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }
    }
}
