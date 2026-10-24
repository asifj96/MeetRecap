import Foundation
import SwiftData

@MainActor
final class LiveRecapRepository: RecapRepository {
    private let context: ModelContext
    private let api: any RecapAPI
    private let connectivity: any Connectivity

    init(context: ModelContext, api: any RecapAPI, connectivity: any Connectivity) {
        self.context = context
        self.api = api
        self.connectivity = connectivity
    }

    func generateRecap(text: String, language: RecapLanguage) async throws -> MeetingRecap {
        let hash = HashUtil.sha256("\(GroqAPI.model)|\(language.rawValue)|\(text)")
        if let cached = try record(hash: hash) {
            return try RecapRecordMapping.domain(cached)
        }
        guard connectivity.isOnline() else {
            throw AppError.noInternet
        }

        let content: String
        do {
            content = try await api.complete(
                systemPrompt: PromptBuilder.systemPrompt(language: language),
                userText: text
            )
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw HTTPErrorMapper.map(urlError: error)
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }

        let payload: RecapPayload
        do {
            let sanitized = JsonSanitizer.sanitize(content)
            payload = try JSONDecoder().decode(RecapPayload.self, from: Data(sanitized.utf8))
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.invalidResponse("malformed recap JSON")
        }

        let recap = payload.meetingRecap(sourceText: text, language: language, contentHash: hash)
        return try insert(recap)
    }

    func history() async -> [MeetingRecap] {
        var descriptor = FetchDescriptor<MeetingRecapRecord>(
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.recordID, order: .reverse)
            ]
        )
        descriptor.fetchLimit = nil
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { try? RecapRecordMapping.domain($0) }
    }

    func recap(id: Int64) async -> MeetingRecap? {
        guard let record = try? record(id: id) else { return nil }
        return try? RecapRecordMapping.domain(record)
    }

    func delete(id: Int64) async {
        guard let record = try? record(id: id) else { return }
        context.delete(record)
        try? context.save()
    }

    private func insert(_ recap: MeetingRecap) throws -> MeetingRecap {
        let nextID = (try context.fetch(FetchDescriptor<MeetingRecapRecord>()).map(\.recordID).max() ?? 0) + 1
        let record = try RecapRecordMapping.encode(recap, id: nextID)
        context.insert(record)
        try context.save()
        return try RecapRecordMapping.domain(record)
    }

    private func record(hash: String) throws -> MeetingRecapRecord? {
        try context.fetch(FetchDescriptor<MeetingRecapRecord>()).first { $0.contentHash == hash }
    }

    private func record(id: Int64) throws -> MeetingRecapRecord? {
        try context.fetch(FetchDescriptor<MeetingRecapRecord>()).first { $0.recordID == id }
    }
}
