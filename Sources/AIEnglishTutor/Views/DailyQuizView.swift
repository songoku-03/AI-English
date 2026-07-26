import SwiftUI
import AppKit

@MainActor
public struct DailyQuizView: View {
    @ObservedObject public var viewModel: AppViewModel

    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var isAnswerSubmitted: Bool = false
    @State private var score: Int = 0
    @State private var isQuizFinished: Bool = false

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

            if viewModel.dailyQuizQuestions.isEmpty {
                emptyQuizView
            } else if isQuizFinished {
                completionView
            } else {
                questionContentView
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "target")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Practice Quiz")
                    .font(.system(size: 16, weight: .bold))
                Text("Master past grammar corrections with instant interactive feedback")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !viewModel.dailyQuizQuestions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Score: \(score)/\(viewModel.dailyQuizQuestions.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.1)))
            }
        }
    }

    private var emptyQuizView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }

            Text("No Practice Questions Available")
                .font(.title2)
                .fontWeight(.bold)

            Text("Complete live audio tutoring sessions with your AI English Tutor! Grammar corrections will automatically generate custom daily quiz questions.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            Button(action: {
                viewModel.selectedTab = 0
            }) {
                Label("Start Learning Session", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currentQuestion: QuizQuestion {
        viewModel.dailyQuizQuestions[currentIndex]
    }

    private var questionContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Progress Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Question \(currentIndex + 1) of \(viewModel.dailyQuizQuestions.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(Double(currentIndex + 1) / Double(viewModel.dailyQuizQuestions.count) * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(viewModel.dailyQuizQuestions.count), height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Question Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Grammar Challenge")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }

                    Text(currentQuestion.questionText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.controlBackgroundColor)))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

                // Options List
                VStack(spacing: 10) {
                    ForEach(0..<currentQuestion.options.count, id: \.self) { index in
                        optionRow(index: index, text: currentQuestion.options[index])
                    }
                }

                // Feedback & Next Button Area
                if isAnswerSubmitted {
                    feedbackCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(24)
            .frame(maxWidth: 680)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func optionRow(index: Int, text: String) -> some View {
        let isCorrect = index == currentQuestion.correctOptionIndex
        let isSelected = index == selectedOptionIndex

        var backgroundColor: Color = Color(NSColor.controlBackgroundColor)
        var borderColor: Color = Color.clear
        var textColor: Color = .primary
        var iconName: String? = nil

        if isAnswerSubmitted {
            if isCorrect {
                backgroundColor = Color.green.opacity(0.15)
                borderColor = Color.green
                textColor = .green
                iconName = "checkmark.circle.fill"
            } else if isSelected {
                backgroundColor = Color.red.opacity(0.15)
                borderColor = Color.red
                textColor = .red
                iconName = "xmark.circle.fill"
            }
        } else if isSelected {
            borderColor = Color.orange
        }

        return Button(action: {
            guard !isAnswerSubmitted else { return }
            selectedOptionIndex = index
            isAnswerSubmitted = true

            if index == currentQuestion.correctOptionIndex {
                score += 1
            }
        }) {
            HStack(spacing: 14) {
                Text(String(UnicodeScalar(65 + index)!))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isSelected ? Color.orange.opacity(0.2) : Color.primary.opacity(0.08)))
                    .foregroundColor(isSelected ? .orange : .primary)

                Text(text)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(textColor)

                Spacer()

                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(textColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(backgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: isSelected || isAnswerSubmitted ? 2 : 0))
        }
        .buttonStyle(.plain)
        .disabled(isAnswerSubmitted)
    }

    private var feedbackCard: some View {
        let isCorrect = selectedOptionIndex == currentQuestion.correctOptionIndex

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCorrect ? .green : .red)
                Text(isCorrect ? "Excellent! Correct Answer 🎉" : "Not Quite Right")
                    .font(.headline)
                    .foregroundColor(isCorrect ? .green : .red)
            }

            if !currentQuestion.explanation.isEmpty {
                Text(currentQuestion.explanation)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button(action: nextQuestion) {
                    Label(currentIndex + 1 < viewModel.dailyQuizQuestions.count ? "Next Question" : "See Results", systemImage: "arrow.right.circle.fill")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isCorrect ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1))
    }

    private func nextQuestion() {
        if currentIndex + 1 < viewModel.dailyQuizQuestions.count {
            currentIndex += 1
            selectedOptionIndex = nil
            isAnswerSubmitted = false
        } else {
            isQuizFinished = true
        }
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            Text("Quiz Completed!")
                .font(.title)
                .fontWeight(.bold)

            Text("You scored \(score) out of \(viewModel.dailyQuizQuestions.count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.orange)

            let percentage = Double(score) / Double(max(1, viewModel.dailyQuizQuestions.count)) * 100
            Text(percentage >= 80 ? "Outstanding progress! Keep practicing daily." : "Great effort! Review past errors in history to strengthen your skills.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button(action: restartQuiz) {
                Label("Restart Quiz", systemImage: "arrow.clockwise.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func restartQuiz() {
        currentIndex = 0
        selectedOptionIndex = nil
        isAnswerSubmitted = false
        score = 0
        isQuizFinished = false
    }
}
