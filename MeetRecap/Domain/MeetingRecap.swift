import Foundation

struct MeetingRecap: Equatable, Sendable {
    var id: Int64
    var sourceText: String
    var language: RecapLanguage
    var tldr: String
    var decisions: [String]
    var actionItems: [ActionItem]
    var nextSteps: [String]
    var followUpEmail: String
    var createdAt: Date
    var contentHash: String

    static let titleLimit = 50

    init(
        id: Int64 = 0,
        sourceText: String,
        language: RecapLanguage,
        tldr: String,
        decisions: [String],
        actionItems: [ActionItem],
        nextSteps: [String],
        followUpEmail: String,
        createdAt: Date,
        contentHash: String = ""
    ) {
        self.id = id
        self.sourceText = sourceText
        self.language = language
        self.tldr = tldr
        self.decisions = decisions
        self.actionItems = actionItems
        self.nextSteps = nextSteps
        self.followUpEmail = followUpEmail
        self.createdAt = createdAt
        self.contentHash = contentHash
    }

    var actionItemCount: Int { actionItems.count }

    var title: String {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(Self.titleLimit))
        if trimmed.count > Self.titleLimit {
            return prefix + "…"
        }
        return prefix
    }
}
