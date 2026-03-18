import Cocoa
import SwiftUI

struct RenamePopoverView: View {
    let currentName: String
    let onRename: (String) -> Void
    let onCancel: () -> Void

    @State private var newName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField("Desktop name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .focused($isTextFieldFocused)
                .onSubmit {
                    submitName()
                }

            HStack(spacing: 8) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    submitName()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .onAppear {
            newName = currentName
            // Auto-focus and select all text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    private func submitName() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onRename(trimmed)
    }
}

final class RenamePopover: NSPopover {
    private let spaceUUID: String
    private let currentName: String
    private let onRename: (String, String) -> Void

    init(spaceUUID: String, currentName: String, onRename: @escaping (String, String) -> Void) {
        self.spaceUUID = spaceUUID
        self.currentName = currentName
        self.onRename = onRename
        super.init()

        self.behavior = .transient
        self.contentSize = NSSize(width: 250, height: 120)

        let view = RenamePopoverView(
            currentName: currentName,
            onRename: { [weak self] newName in
                guard let self else { return }
                self.onRename(self.spaceUUID, newName)
                self.performClose(nil)
            },
            onCancel: { [weak self] in
                self?.performClose(nil)
            }
        )
        self.contentViewController = NSHostingController(rootView: view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
