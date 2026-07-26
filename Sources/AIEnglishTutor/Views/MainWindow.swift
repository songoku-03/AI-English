import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public struct MainWindow: View {
    @ObservedObject public var viewModel: AppViewModel
    @State private var apiKeyInput: String = ""
    @State private var showApiKey: Bool = false
    @State private var exportedText: String? = nil
    @State private var showSavedToast: Bool = false

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
        TabView(selection: $viewModel.selectedTab) {
            liveTutorView
                .tabItem {
                    Label("Live Tutor", systemImage: "mic.fill")
                }
                .tag(0)

            HistoryView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)

            DailyQuizView(viewModel: viewModel)
                .tabItem {
                    Label("Daily Quiz", systemImage: "target")
                }
                .tag(2)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .frame(minWidth: 880, minHeight: 620)
        .sheet(isPresented: $viewModel.showScreenPickerModal) {
            ScreenPickerModal(viewModel: viewModel)
        }
        .onAppear {
            apiKeyInput = viewModel.config.apiKey
            Task {
                await viewModel.fetchAvailableDisplays()
            }
        }
    }

    // MARK: - Subviews

    private var liveTutorView: some View {
        VStack(spacing: 0) {
            if !viewModel.hasScreenPermission {
                permissionWarningBanner
            }

            // Header Bar
            headerView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Material.thinMaterial)

            Divider()

            // Main Content Area (Sidebar + Chat Area)
            HStack(spacing: 0) {
                // Left Control Panel / Sidebar
                sidebarView
                    .frame(width: 320)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

                Divider()

                // Right Transcript & Live View
                transcriptView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var permissionWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Recording Permission Required")
                    .font(.system(size: 13, weight: .bold))
                Text("System permission is required to capture screen frames for visual tutoring.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                viewModel.openScreenCaptureSettings()
            }) {
                Label("Open System Settings", systemImage: "gear")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.regular)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AI English Tutor")
                    .font(.system(size: 16, weight: .bold))
                Text("Realtime Voice & Screen Learning Assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isSessionActive ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(viewModel.isSessionActive ? "Live Session" : "Offline")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.isSessionActive ? .green : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }

    private var sidebarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Controls Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Controls")
                        .font(.headline)

                    Button(action: {
                        Task {
                            await viewModel.toggleSession()
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.isSessionActive ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title3)
                            Text(viewModel.isSessionActive ? "Stop Session (⌃⌥S)" : "Start Session (⌃⌥S)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isSessionActive ? .red : .blue)
                    .controlSize(.large)

                    Button(action: {
                        viewModel.toggleMute()
                    }) {
                        HStack {
                            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                            Text(viewModel.isMuted ? "Unmute Mic (⌃⌥M)" : "Mute Mic (⌃⌥M)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.isMuted ? .red : .primary)

                    Text("Status: \(viewModel.statusMessage)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Microphone Realtime Audio Level Meter
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "waveform")
                            .foregroundColor(viewModel.isMuted ? .red : (viewModel.audioLevel > 0.05 ? .green : .secondary))
                            .font(.caption)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.12))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .teal, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(viewModel.isMuted ? 0.0 : viewModel.audioLevel))
                            }
                        }
                        .frame(height: 8)

                        Text(viewModel.isMuted ? "MUTED" : "\(Int(viewModel.audioLevel * 100))%")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(viewModel.isMuted ? .red : (viewModel.audioLevel > 0.05 ? .green : .secondary))
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.top, 2)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))

                // 2. Realtime Screen Live Preview Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "rectangle.inset.filled.and.person.filled")
                            .foregroundColor(.green)
                        Text("Live Screen Preview")
                            .font(.headline)
                        Spacer()
                        if viewModel.isSessionActive {
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text("REC \(viewModel.selectedFPS)FPS")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                            .frame(height: 160)

                        if let frameImage = viewModel.latestFrameImage {
                            Image(nsImage: frameImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 160)
                                .cornerRadius(8)
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "desktopcomputer")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                Text(viewModel.isSessionActive ? "Waiting for initial frame..." : "Preview Offline")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))

                // 3. Display Picker Card
                VStack(alignment: .leading, spacing: 10) {
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
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.availableDisplays.isEmpty {
                        Text("Detecting displays...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Screen", selection: $viewModel.selectedDisplayID) {
                            ForEach(viewModel.availableDisplays) { display in
                                Text(display.displayName)
                                    .tag(Optional(display.id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Captures screen frames for AI visual context.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))

                // 4. Stream Quality & FPS Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.orange)
                        Text("Stream Quality & FPS")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Frame Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Frame Rate", selection: $viewModel.selectedFPS) {
                            Text("1 FPS (AI Standard)").tag(1)
                            Text("2 FPS").tag(2)
                            Text("5 FPS").tag(5)
                            Text("15 FPS").tag(15)
                            Text("30 FPS (High)").tag(30)
                            Text("60 FPS (Ultra Smooth)").tag(60)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()

                        Text("Resolution")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Resolution", selection: $viewModel.selectedResolutionDimension) {
                            Text("720p HD (1280px)").tag(1280)
                            Text("1080p Full HD (1920px)").tag(1920)
                            Text("Native 4K").tag(0)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))


                // 3. API Key Status Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                        Text("Gemini API Key")
                            .font(.headline)
                        Spacer()
                        if showSavedToast {
                            Text("Saved!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }

                    HStack(spacing: 6) {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showSavedToast = false }
                        }
                    }) {
                        Label("Save API Key", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
            }
            .padding(16)
        }
    }

    private var transcriptView: some View {
        VStack(spacing: 0) {
            // Live Subtitle Header
            if !viewModel.liveSubtitle.isEmpty || viewModel.isSessionActive {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text(viewModel.liveSubtitle.isEmpty ? "Listening & Watching..." : viewModel.liveSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                .padding(14)
            }

            // Transcript Header & Export Button
            HStack {
                Text("Session Transcript")
                    .font(.headline)

                Spacer()

                Button(action: exportTranscript) {
                    Label("Export (.txt)", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Chat Scroll List
            if viewModel.transcripts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Conversation History Yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Save your API Key and click Start Session to begin speaking with your AI English Tutor.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 320)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.transcripts) { entry in
                                chatBubble(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: viewModel.transcripts.count) { oldValue, newValue in
                        if let lastID = viewModel.transcripts.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Pinned Bottom Live Preview & Subtitle Bar
            if viewModel.isSessionActive {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.8))
                                .frame(width: 84, height: 52)

                            if let frameImage = viewModel.latestFrameImage {
                                Image(nsImage: frameImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 84, height: 52)
                                    .cornerRadius(6)
                            } else {
                                Image(systemName: "desktopcomputer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text("LIVE STREAM SCREEN (\(viewModel.selectedFPS) FPS)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                            }

                            Text(viewModel.liveSubtitle.isEmpty ? (viewModel.transcripts.last?.text ?? "AI Tutor is listening & watching live screen...") : viewModel.liveSubtitle)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
    }

    private func chatBubble(entry: TranscriptEntry) -> some View {
        let isUser = entry.speaker.lowercased().contains("user") || entry.speaker.lowercased().contains("learner")
        let isSystem = entry.speaker.lowercased().contains("system")

        return HStack {
            if isUser { Spacer() }

            if isSystem {
                Text(entry.text)
                    .font(.caption)
                    .italic()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            } else {
                HStack(alignment: .top, spacing: 10) {
                    if !isUser {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.blue.opacity(0.15)))
                    }

                    VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                        Text(entry.speaker)
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.secondary)

                        Text(entry.text)
                            .font(.body)
                            .foregroundColor(isUser ? .white : .primary)
                    }

                    if isUser {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.blue))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isUser ? Color.blue : Color(NSColor.controlBackgroundColor))
                )
                .frame(maxWidth: 480, alignment: isUser ? .trailing : .leading)
            }

            if !isUser && !isSystem { Spacer() }
        }
    }
}



