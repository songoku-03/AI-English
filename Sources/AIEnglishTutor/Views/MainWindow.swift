import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public struct MainWindow: View {
    @ObservedObject public var viewModel: AppViewModel
    @State private var apiKeyInput: String = ""
    @State private var exportedText: String? = nil

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public func exportTranscript() {
        let transcriptText = viewModel.exportTranscript()
        exportedText = transcriptText

        let savePanel = NSSavePanel()
        savePanel.title = "Save Transcript"
        savePanel.nameFieldStringValue = "Transcript.txt"
        if #available(macOS 12.0, *) {
            savePanel.allowedContentTypes = [.plainText]
        } else {
            savePanel.allowedFileTypes = ["txt"]
        }

        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                try? transcriptText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI English Tutor - Setup & Transcripts")
                .font(.title2)
                .bold()

            HStack {
                SecureField("Enter Gemini API Key", text: $apiKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Save API Key") {
                    try? viewModel.saveAPIKey(apiKeyInput)
                }
            }

            HStack(spacing: 12) {
                Button(viewModel.isSessionActive ? "Stop Session (⌃⌥S)" : "Start Session (⌃⌥S)") {
                    Task {
                        await viewModel.toggleSession()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(viewModel.isMuted ? "Unmute Mic (⌃⌥M)" : "Mute Mic (⌃⌥M)") {
                    viewModel.toggleMute()
                }

                Spacer()

                Button("Export Transcript (.txt)") {
                    exportTranscript()
                }
            }

            Text("Status: \(viewModel.statusMessage)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            Text("Session Transcript")
                .font(.headline)

            List(viewModel.transcripts) { entry in
                HStack(alignment: .top) {
                    Text("\(entry.speaker):")
                        .bold()
                        .foregroundColor(entry.speaker == "Tutor" ? .blue : .primary)
                    Text(entry.text)
                }
            }

            if let export = exportedText {
                Text("Export Output:")
                    .font(.caption)
                    .bold()
                TextEditor(text: .constant(export))
                    .frame(height: 80)
            }
        }
        .padding()
        .frame(minWidth: 550, minHeight: 450)
        .onAppear {
            apiKeyInput = viewModel.config.apiKey
        }
    }
}

