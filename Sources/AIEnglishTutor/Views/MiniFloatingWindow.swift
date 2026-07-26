import SwiftUI
import AppKit

@MainActor
public struct MiniFloatingWindow: View {
    @ObservedObject public var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(viewModel.isSessionActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isMuted ? "[MUTED]" : (viewModel.isSessionActive ? "Live Session" : "Offline"))
                    .font(.caption2)
                    .bold()
                    .foregroundColor(viewModel.isMuted ? .red : .primary)
                Text(viewModel.liveSubtitle.isEmpty ? (viewModel.transcripts.last?.text ?? "Ready") : viewModel.liveSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Material.thinMaterial)
        .cornerRadius(10)
    }

    public static func createFloatingWindow(viewModel: AppViewModel) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: MiniFloatingWindow(viewModel: viewModel))
        return window
    }
}
