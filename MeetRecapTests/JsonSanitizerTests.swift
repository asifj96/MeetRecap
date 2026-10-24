import Foundation
import Testing
@testable import MeetRecap

struct JsonSanitizerTests {
    @Test
    func extractsObjectFromMarkdownFence() {
        let raw = """
        Here is the recap:
        ```json
        {"tldr":"Done","decisions":[]}
        ```
        """
        #expect(JsonSanitizer.sanitize(raw) == "{\"tldr\":\"Done\",\"decisions\":[]}")
    }

    @Test
    func returnsTrimmedTextWhenBracesAreMissing() {
        #expect(JsonSanitizer.sanitize("  not json  ") == "not json")
    }
}

struct HTTPErrorMapperTests {
    @Test
    func mapsRateLimitAndServerErrors() {
        #expect(HTTPErrorMapper.map(status: 429, details: "slow down") == .rateLimited)
        #expect(HTTPErrorMapper.map(status: 408, details: "") == .timeout)
        #expect(HTTPErrorMapper.map(status: 503, details: "down") == .apiError(code: 503, details: "server error"))
        #expect(HTTPErrorMapper.map(status: 400, details: "bad") == .apiError(code: 400, details: "bad"))
    }
}

struct ShareTextTests {
    @Test
    func shareTextKeepsSectionOrder() {
        let recap = MeetingRecap(
            sourceText: String(repeating: "a", count: 100),
            language: .english,
            tldr: "Short summary",
            decisions: ["Ship it"],
            actionItems: [ActionItem(task: "Write notes", owner: "Ada", due: "Friday")],
            nextSteps: ["Review"],
            followUpEmail: "Hello team",
            createdAt: .now
        )
        #expect(recap.shareText() == """
        Summary
        Short summary

        Decisions
        - Ship it

        Action Items
        - Write notes (owner: Ada, due: Friday)

        Next Steps
        - Review

        Follow-up Email
        Hello team
        """)
    }
}
