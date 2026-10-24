import Foundation

@MainActor
protocol RecapRepository: AnyObject {
    func generateRecap(text: String, language: RecapLanguage) async throws -> MeetingRecap
    func history() async -> [MeetingRecap]
    func recap(id: Int64) async -> MeetingRecap?
    func delete(id: Int64) async
}
