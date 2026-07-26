import SwiftUI
import AppKit

@MainActor
public struct SettingsView: View {
    @ObservedObject public var viewModel: AppViewModel
    @State private var apiKeyInput: String = ""
    @State private var showApiKey: Bool = false
    @State private var showSavedToast: Bool = false

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Material.thinMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // 1. Gemini API Key Card
                    apiKeyCard

                    // 2. Screen Capture Display Selection
                    screenCaptureCard

                    // 3. Stream Quality & FPS Card
                    streamQualityCard

                    // 4. Model & Shortcuts Card
                    modelAndShortcutsCard
                }
                .padding(24)
                .frame(maxWidth: 680)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            apiKeyInput = viewModel.config.apiKey
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Settings & Configuration")
                    .font(.system(size: 16, weight: .bold))
                Text("Manage API credentials, capture source, and tutor preferences")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                Text("Gemini API Key")
                    .font(.headline)
                Spacer()
                if showSavedToast {
                    Text("Key Saved Securely!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }

            Text("Your API Key is stored securely in your macOS Keychain.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                if showApiKey {
                    TextField("Enter Gemini API Key", text: $apiKeyInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    SecureField("Enter Gemini API Key", text: $apiKeyInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Button(action: { showApiKey.toggle() }) {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                try? viewModel.saveAPIKey(apiKeyInput)
                withAnimation {
                    showSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showSavedToast = false }
                }
            }) {
                Label("Save Key to Keychain", systemImage: "lock.doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.controlBackgroundColor)))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var screenCaptureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "display.2")
                    .foregroundColor(.purple)
                Text("Screen Capture Source")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.fetchAvailableDisplays()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Select which monitor/display the AI Tutor should watch during your session.")
                .font(.caption)
                .foregroundColor(.secondary)

            if viewModel.availableDisplays.isEmpty {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Detecting available displays...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Picker("Capture Display", selection: $viewModel.selectedDisplayID) {
                    ForEach(viewModel.availableDisplays) { display in
                        Text(display.displayName)
                            .tag(Optional(display.id))
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.controlBackgroundColor)))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var streamQualityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.orange)
                Text("Stream Quality & FPS")
                    .font(.headline)
            }

            Text("Adjust capture frame rate and resolution transmitted to the AI model.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Frame Rate (FPS)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Frame Rate", selection: $viewModel.selectedFPS) {
                        Text("1 FPS (AI Standard)").tag(1)
                        Text("2 FPS").tag(2)
                        Text("5 FPS").tag(5)
                        Text("15 FPS").tag(15)
                        Text("30 FPS (High)").tag(30)
                        Text("60 FPS (Ultra Smooth)").tag(60)
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Divider()

                HStack {
                    Text("Target Resolution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Resolution", selection: $viewModel.selectedResolutionDimension) {
                        Text("720p HD (1280px)").tag(1280)
                        Text("1080p Full HD (1920px)").tag(1920)
                        Text("Native 4K").tag(0)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.controlBackgroundColor)))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var modelAndShortcutsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.teal)
                Text("AI Model & Global Hotkeys")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current Active Model:")
                        .font(.subheadline)
                    Spacer()
                    Text(viewModel.currentModel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.teal.opacity(0.15)))
                        .foregroundColor(.teal)
                }

                Divider()

                Text("Global Hotkey Shortcuts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Label("Start / Stop Session", systemImage: "play.circle")
                        .font(.caption)
                    Spacer()
                    Text("⌃⌥S")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                }

                HStack {
                    Label("Toggle Mute Microphone", systemImage: "mic.slash")
                        .font(.caption)
                    Spacer()
                    Text("⌃⌥M")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.controlBackgroundColor)))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
