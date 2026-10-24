import Foundation
import SwiftData
import Testing
@testable import MeetRecap

@Suite(.serialized)
struct RecapRepositoryTests {
    @Test
    @MainActor
    func returnsCachedRecapWithoutCallingTheProxyAgain() async throws {
        let api = StubRecapAPI()
        let repository = try makeRepository(api: api, connectivity: OnlineConnectivity())
        let text = String(repeating: "m", count: 120)

        let first = try await repository.generateRecap(text: text, language: .english)
        let second = try await repository.generateRecap(text: text, language: .english)

        #expect(first.tldr == "Saved")
        #expect(second.id == first.id)
        #expect(api.calls == 1)
    }

    @Test
    @MainActor
    func eachLanguageDecodesARecap() async throws {
        let api = StubRecapAPI()
        let repository = try makeRepository(api: api, connectivity: OnlineConnectivity())
        for language in RecapLanguage.allCases {
            api.payload = payload(tldr: language.instruction)
            let text = String(repeating: language.rawValue, count: 40)
            let recap = try await repository.generateRecap(text: text, language: language)
            #expect(recap.language == language)
            #expect(recap.tldr == language.instruction)
        }
        #expect(api.calls == RecapLanguage.allCases.count)
    }

    @Test
    @MainActor
    func offlineMissThrowsNoInternet() async {
        let repository = try? makeRepository(api: StubRecapAPI(), connectivity: OfflineConnectivity())
        let failure: AppError? = await {
            guard let repository else { return nil }
            do {
                _ = try await repository.generateRecap(
                    text: String(repeating: "z", count: 120),
                    language: .arabic
                )
                return nil
            } catch let error as AppError {
                return error
            } catch {
                return .unknown(error.localizedDescription)
            }
        }()
        #expect(failure == .noInternet)
    }

    @Test
    @MainActor
    func historyIsNewestFirstAndDeleteRemovesTheRow() async throws {
        let api = StubRecapAPI()
        let repository = try makeRepository(api: api, connectivity: OnlineConnectivity())
        let older = try await repository.generateRecap(text: String(repeating: "o", count: 120), language: .english)
        let newer = try await repository.generateRecap(text: String(repeating: "n", count: 120), language: .urdu)

        let listed = await repository.history()
        #expect(listed.map(\.id) == [newer.id, older.id])

        await repository.delete(id: newer.id)
        let remaining = await repository.history()
        #expect(remaining.map(\.id) == [older.id])
        let loaded = await repository.recap(id: older.id)
        #expect(loaded?.sourceText == older.sourceText)
    }
}

@MainActor
private func makeRepository(api: StubRecapAPI, connectivity: any Connectivity) throws -> LiveRecapRepository {
    let context = AppModelStore.container.mainContext
    for record in try context.fetch(FetchDescriptor<MeetingRecapRecord>()) {
        context.delete(record)
    }
    try context.save()
    return LiveRecapRepository(context: context, api: api, connectivity: connectivity)
}

private func payload(tldr: String) -> String {
    """
    ```json
    {"tldr":"\(tldr)","decisions":["d"],"actionItems":[{"task":"t","owner":null,"due":null}],"nextSteps":["n"],"followUpEmail":"email"}
    ```
    """
}

final class StubRecapAPI: RecapAPI, @unchecked Sendable {
    var calls = 0
    var payload = #"{"tldr":"Saved","decisions":[],"actionItems":[],"nextSteps":[],"followUpEmail":""}"#

    func complete(systemPrompt: String, userText: String) async throws -> String {
        calls += 1
        return payload
    }
}
