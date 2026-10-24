import Foundation

enum PromptBuilder {
    static let maxTokens = 1500

    static func systemPrompt(language: RecapLanguage) -> String {
        """
        You are a meeting-recap engine. Read the user's meeting notes or transcript and extract a \
        structured recap. Respond with a single JSON object and nothing else, using exactly these keys:

        {
          "tldr": string,                 // 1-3 sentence summary of the meeting
          "decisions": string[],          // key decisions made
          "actionItems": [                // concrete follow-up tasks
            { "task": string, "owner": string|null, "due": string|null }
          ],
          "nextSteps": string[],          // planned next steps
          "followUpEmail": string         // a short, ready-to-send follow-up email
        }

        Write every text value in \(language.instruction). If a field has no content, use an empty \
        array or empty string. Do not include commentary outside the JSON.
        """
    }
}
