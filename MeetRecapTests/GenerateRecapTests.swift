import Foundation
import Testing
@testable import MeetRecap

struct GenerateRecapTests {
    @Test
    @MainActor
    func rejectsTextShorterThanMinimum() async {
        let repository = FakeRecapRepository()
        let generate = GenerateRecap(repository: repository)

        await #expect(throws: AppError.invalidInput) {
            try await generate(text: "too short", language: .english)
        }
        #expect(repository.generateCalls == 0)
    }

    @Test
    @MainActor
    func acceptsOneHundredCharacters() async throws {
        let repository = FakeRecapRepository()
        let generate = GenerateRecap(repository: repository)
        let text = String(repeating: "a", count: 100)

        let recap = try await generate(text: text, language: .english)

        #expect(recap.sourceText == text)
        #expect(repository.generateCalls == 1)
    }

    @Test
    @MainActor
    func rejectsTextLongerThanMaximum() async {
        let repository = FakeRecapRepository()
        let generate = GenerateRecap(repository: repository)
        let text = String(repeating: "a", count: GenerateRecap.maximumLength + 1)

        await #expect(throws: AppError.invalidInput) {
            try await generate(text: text, language: .english)
        }
        #expect(repository.generateCalls == 0)
    }

    @Test
    func titleStopsAtFiftyCharacters() {
        let source = String(repeating: "b", count: 60)
        let recap = MeetingRecap(
            sourceText: source,
            language: .english,
            tldr: "",
            decisions: [],
            actionItems: [],
            nextSteps: [],
            followUpEmail: "",
            createdAt: .now
        )
        #expect(recap.title == String(repeating: "b", count: 50) + "…")
    }
}

@MainActor
final class FakeRecapRepository: RecapRepository {
    private(set) var generateCalls = 0

    func generateRecap(text: String, language: RecapLanguage) async throws -> MeetingRecap {
        generateCalls += 1
        return MeetingRecap(
            id: 1,
            sourceText: text,
            language: language,
            tldr: "recap",
            decisions: [],
            actionItems: [],
            nextSteps: [],
            followUpEmail: "",
            createdAt: .now
        )
    }

    func history() async -> [MeetingRecap] { [] }
    func recap(id: Int64) async -> MeetingRecap? { nil }
    func delete(id: Int64) async {}
}
