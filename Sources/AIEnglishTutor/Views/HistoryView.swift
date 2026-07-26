import SwiftUI
import AppKit

@MainActor
public struct HistoryView: View {
    @ObservedObject public var viewModel: AppViewModel
    @State private var selectedSessionID: UUID?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

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

            if viewModel.savedSessions.isEmpty {
                emptyStateView
            } else {
                HStack(spacing: 0) {
                    // Left Session List
                    sessionListView
                        .frame(width: 320)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

                    Divider()

                    // Right Session Detail
                    sessionDetailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            if selectedSessionID == nil, let first = viewModel.savedSessions.first {
                selectedSessionID = first.id
            }
        }
        .onChange(of: viewModel.savedSessions) { _, newSessions in
            if selectedSessionID == nil || !newSessions.contains(where: { $0.id == selectedSessionID }) {
                selectedSessionID = newSessions.first?.id
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Session History")
                    .font(.system(size: 16, weight: .bold))
                Text("Review past tutoring sessions and grammar corrections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "tray.full.fill")
                    .font(.caption)
                    .foregroundColor(.indigo)
                Text("\(viewModel.savedSessions.count) Sessions")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.indigo.opacity(0.1)))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundColor(.indigo)
            }

            Text("No Recorded Sessions Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Start a Live Tutor session. When finished, your complete transcripts and AI grammar corrections will be automatically saved here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button(action: {
                viewModel.selectedTab = 0
            }) {
                Label("Start Live Session", systemImage: "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.savedSessions) { session in
                    sessionRow(session)
                }
            }
            .padding(12)
        }
    }

    private func sessionRow(_ session: SessionRecord) -> some View {
        let isSelected = session.id == selectedSessionID

        return Button(action: {
            selectedSessionID = session.id
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Self.dateFormatter.string(from: session.date))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                    Spacer()
                    Text(formatDuration(session.durationSeconds))
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                HStack(spacing: 12) {
                    Label("\(session.transcripts.count)", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.caption2)

                    if !session.extractedErrors.isEmpty {
                        Label("\(session.extractedErrors.count) errors", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white : .orange)
                    }
                }
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.indigo : Color(NSColor.controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }

    private var currentSelectedSession: SessionRecord? {
        viewModel.savedSessions.first(where: { $0.id == selectedSessionID })
    }

    private var sessionDetailView: some View {
        VStack(spacing: 0) {
            if let session = currentSelectedSession {
                // Top Session Meta Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dateFormatter.string(from: session.date))
                            .font(.headline)
                        Text("Duration: \(formatDuration(session.durationSeconds)) • \(session.transcripts.count) Messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            await viewModel.deleteSession(id: session.id)
                        }
                    }) {
                        Label("Delete Session", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Extracted Grammar Errors Section
                        if !session.extractedErrors.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "text.badge.checkmark")
                                        .foregroundColor(.indigo)
                                    Text("Grammar Corrections (\(session.extractedErrors.count))")
                                        .font(.headline)
                                }

                                ForEach(session.extractedErrors) { errorItem in
                                    extractedErrorCard(errorItem)
                                }
                            }
                        }

                        // Transcripts Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.blue)
                                Text("Transcript Details")
                                    .font(.headline)
                            }

                            LazyVStack(spacing: 10) {
                                ForEach(session.transcripts) { entry in
                                    transcriptCard(entry)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Select a session from the list to view details")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func extractedErrorCard(_ errorItem: ExtractedErrorItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(errorItem.category.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                    .foregroundColor(.orange)
                Spacer()
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(errorItem.originalSentence)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .strikethrough()
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(errorItem.correctedSentence)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            if !errorItem.explanation.isEmpty {
                Text("💡 \(errorItem.explanation)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private func transcriptCard(_ entry: TranscriptEntry) -> some View {
        let isUser = entry.speaker.lowercased().contains("user") || entry.speaker.lowercased().contains("learner")

        return HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(entry.speaker)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.secondary)

                Text(entry.text)
                    .font(.body)
                    .foregroundColor(isUser ? .white : .primary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUser ? Color.blue : Color(NSColor.controlBackgroundColor))
            )
            .frame(maxWidth: 440, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer() }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainderSeconds = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(remainderSeconds)s"
        }
        return "\(remainderSeconds)s"
    }
}
