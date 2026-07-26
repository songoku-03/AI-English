import Foundation

public struct QuizGeneratorService: Sendable {
    public static func generateQuiz(from sessions: [SessionRecord]) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let allErrors = sessions.flatMap { $0.extractedErrors }

        for error in allErrors {
            let correctOption = error.correctedSentence
            let wrongOption1 = error.originalSentence
            let wrongOption2 = error.originalSentence.replacingOccurrences(of: "don't", with: "not")
            let options = [correctOption, wrongOption1, wrongOption2].shuffled()
            let correctIndex = options.firstIndex(of: correctOption) ?? 0

            let question = QuizQuestion(
                questionText: "How should you correctly say: \"\(error.originalSentence)\"?",
                options: options,
                correctOptionIndex: correctIndex,
                explanation: error.explanation
            )
            questions.append(question)
        }
        return questions
    }
}
