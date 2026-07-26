import SwiftUI

@MainActor
public struct MenuBarView: View {
    @ObservedObject public var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI English Tutor")
                .font(.headline)
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Button(viewModel.isSessionActive ? "Stop Session (⌃⌥S)" : "Start Session (⌃⌥S)") {
                Task {
                    await viewModel.toggleSession()
                }
            }
            Button(viewModel.isMuted ? "Unmute Mic (⌃⌥M)" : "Mute Mic (⌃⌥M)") {
                viewModel.toggleMute()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
    }
}
