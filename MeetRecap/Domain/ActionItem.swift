import Foundation

struct ActionItem: Codable, Equatable, Sendable {
    var task: String
    var owner: String?
    var due: String?

    init(task: String, owner: String? = nil, due: String? = nil) {
        self.task = task
        self.owner = owner
        self.due = due
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        task = try container.decodeIfPresent(String.self, forKey: .task) ?? ""
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        due = try container.decodeIfPresent(String.self, forKey: .due)
    }
}
