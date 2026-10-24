import Foundation
import SwiftData

@Model
final class MeetingRecapRecord {
    var recordID: Int64
    var sourceText: String
    var languageRaw: String
    var tldr: String
    var decisionsJSON: String
    var actionItemsJSON: String
    var nextStepsJSON: String
    var followUpEmail: String
    var createdAt: Date
    var contentHash: String

    init(
        recordID: Int64,
        sourceText: String,
        languageRaw: String,
        tldr: String,
        decisionsJSON: String,
        actionItemsJSON: String,
        nextStepsJSON: String,
        followUpEmail: String,
        createdAt: Date,
        contentHash: String
    ) {
        self.recordID = recordID
        self.sourceText = sourceText
        self.languageRaw = languageRaw
        self.tldr = tldr
        self.decisionsJSON = decisionsJSON
        self.actionItemsJSON = actionItemsJSON
        self.nextStepsJSON = nextStepsJSON
        self.followUpEmail = followUpEmail
        self.createdAt = createdAt
        self.contentHash = contentHash
    }
}

enum RecapRecordMapping {
    static func encode(_ recap: MeetingRecap, id: Int64) throws -> MeetingRecapRecord {
        let encoder = JSONEncoder()
        return MeetingRecapRecord(
            recordID: id,
            sourceText: recap.sourceText,
            languageRaw: recap.language.rawValue,
            tldr: recap.tldr,
            decisionsJSON: try jsonString(encoder.encode(recap.decisions)),
            actionItemsJSON: try jsonString(encoder.encode(recap.actionItems)),
            nextStepsJSON: try jsonString(encoder.encode(recap.nextSteps)),
            followUpEmail: recap.followUpEmail,
            createdAt: recap.createdAt,
            contentHash: recap.contentHash
        )
    }

    static func domain(_ record: MeetingRecapRecord) throws -> MeetingRecap {
        let decoder = JSONDecoder()
        let language = RecapLanguage(rawValue: record.languageRaw) ?? .english
        return MeetingRecap(
            id: record.recordID,
            sourceText: record.sourceText,
            language: language,
            tldr: record.tldr,
            decisions: try decoder.decode([String].self, from: Data(record.decisionsJSON.utf8)),
            actionItems: try decoder.decode([ActionItem].self, from: Data(record.actionItemsJSON.utf8)),
            nextSteps: try decoder.decode([String].self, from: Data(record.nextStepsJSON.utf8)),
            followUpEmail: record.followUpEmail,
            createdAt: record.createdAt,
            contentHash: record.contentHash
        )
    }

    private static func jsonString(_ data: Data) throws -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            throw AppError.unknown("Could not store recap.")
        }
        return text
    }
}

struct RecapPayload: Decodable {
    var tldr: String
    var decisions: [String]
    var actionItems: [ActionItem]
    var nextSteps: [String]
    var followUpEmail: String

    private enum CodingKeys: String, CodingKey {
        case tldr, decisions, actionItems, nextSteps, followUpEmail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tldr = try container.decodeIfPresent(String.self, forKey: .tldr) ?? ""
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions) ?? []
        actionItems = try container.decodeIfPresent([ActionItem].self, forKey: .actionItems) ?? []
        nextSteps = try container.decodeIfPresent([String].self, forKey: .nextSteps) ?? []
        followUpEmail = try container.decodeIfPresent(String.self, forKey: .followUpEmail) ?? ""
    }

    func meetingRecap(sourceText: String, language: RecapLanguage, contentHash: String) -> MeetingRecap {
        MeetingRecap(
            sourceText: sourceText,
            language: language,
            tldr: tldr,
            decisions: decisions,
            actionItems: actionItems,
            nextSteps: nextSteps,
            followUpEmail: followUpEmail,
            createdAt: .now,
            contentHash: contentHash
        )
    }
}
