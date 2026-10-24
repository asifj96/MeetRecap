import Foundation

@MainActor
struct GenerateRecap {
    static let minimumLength = 100
    static let maximumLength = 10_000

    private let repository: any RecapRepository

    init(repository: any RecapRepository) {
        self.repository = repository
    }

    func callAsFunction(text: String, language: RecapLanguage) async throws -> MeetingRecap {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumLength, trimmed.count <= Self.maximumLength else {
            throw AppError.invalidInput
        }
        return try await repository.generateRecap(text: trimmed, language: language)
    }
}
