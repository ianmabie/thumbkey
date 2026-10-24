import AppKit
import SwiftUI

/// System glass for floating controls; macOS supplies contrast and accessibility behavior.
struct SystemFloatingSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// A native SwiftUI button; AppKit is used only to capture physical key events.
struct ShortcutRecorderButton: View {
    let label: String
    let recording: Bool
    var enabled = true
    let begin: () -> Void
    var body: some View {
        Button(action: begin) {
            HStack(spacing: 8) {
                Image(systemName: recording ? "record.circle" : "keyboard")
                Text(recording ? "Press your keys · Esc cancels" : label).lineLimit(1)
                Spacer(minLength: 6)
                Text(recording ? "Listening" : "Record shortcut").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).controlSize(.large).disabled(!enabled)
        .accessibilityLabel(recording ? "Recording shortcut. Press Escape to cancel." : "Shortcut: " + label + ". Click to record.")
    }
}
