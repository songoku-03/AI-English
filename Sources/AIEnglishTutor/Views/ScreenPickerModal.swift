import SwiftUI
import AppKit

@MainActor
public struct ScreenPickerModal: View {
    @ObservedObject public var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "display.2")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Select Display to Share")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Choose which monitor your AI Tutor will monitor for real-time visual assistance.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Divider()

            // Display Grid
            if viewModel.availableDisplays.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Detecting displays...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.availableDisplays) { display in
                            displayCard(display: display)
                        }
                    }
                    .padding(24)
                }
            }

            Divider()

            // Actions Footer
            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.showScreenPickerModal = false
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()

                Button(action: {
                    Task {
                        await viewModel.confirmScreenSelectionAndStartSession()
                    }
                }) {
                    Label("Start Sharing Selected Screen", systemImage: "play.fill")
                        .fontWeight(.semibold)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(viewModel.selectedDisplayID == nil)
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 24)
        }
        .frame(width: 680, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func displayCard(display: DisplayInfo) -> some View {
        let isSelected = viewModel.selectedDisplayID == display.id

        Button(action: {
            viewModel.selectedDisplayID = display.id
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Thumbnail Box
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                        .aspectRatio(16 / 9, contentMode: .fit)

                    if let thumbnail = display.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("\(display.width) × \(display.height)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if display.isMain {
                        Text("MAIN DISPLAY")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.blue))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }

                // Info Footer inside card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(display.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text("\(display.width) × \(display.height)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.primary.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
