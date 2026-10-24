import Foundation

enum JsonSanitizer {
    static func sanitize(_ raw: String) -> String {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              end > start else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(raw[start...end])
    }
}
