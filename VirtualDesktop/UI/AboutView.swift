import Cocoa
import SwiftUI

struct AboutView: View {
    private let appVersion: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(version) (Build \(build))"
    }()

    private let copyright: String = {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }()

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("VirtualDesktop")
                .font(.system(size: 20, weight: .bold))

            Text(appVersion)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Name your virtual desktops, see colored borders per desktop, and identify desktops in Mission Control.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Text(copyright)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("Built with Swift and SwiftUI")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            Text("1.0.0: Initial release with desktop naming, colored borders, and Mission Control identifiers.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 340)
    }
}

final class AboutWindowController {
    private var window: NSWindow?

    func showAbout() {
        if window == nil {
            let w = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "About VirtualDesktop"
            w.contentView = NSHostingView(rootView: AboutView())
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
