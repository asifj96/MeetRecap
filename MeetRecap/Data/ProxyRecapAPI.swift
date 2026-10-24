import Foundation

enum GroqAPI {
    static let model = "openai/gpt-oss-120b"
}

protocol RecapAPI: Sendable {
    func complete(systemPrompt: String, userText: String) async throws -> String
}

enum HTTPErrorMapper {
    static func map(status: Int, details: String) -> AppError {
        switch status {
        case 429:
            return .rateLimited
        case 408:
            return .timeout
        case 500...599:
            return .apiError(code: status, details: "server error")
        default:
            let message = details.trimmingCharacters(in: .whitespacesAndNewlines)
            return .apiError(code: status, details: message.isEmpty ? "request failed" : message)
        }
    }

    static func map(urlError: URLError) -> AppError {
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed,
             .cannotFindHost, .dataNotAllowed:
            return .noInternet
        default:
            return .unknown(urlError.localizedDescription)
        }
    }
}

struct ProxyRecapAPI: RecapAPI {
    var session: URLSession
    var baseURL: URL
    var logBodies: Bool

    init(session: URLSession = .shared, baseURL: URL = ProxyConfig.baseURL, logBodies: Bool = true) {
        self.session = session
        self.baseURL = baseURL
        self.logBodies = logBodies
    }

    func complete(systemPrompt: String, userText: String) async throws -> String {
        let endpoint = baseURL.appending(path: "recap")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GroqRequestBody(
                model: GroqAPI.model,
                maxTokens: PromptBuilder.maxTokens,
                messages: [
                    GroqMessage(role: "system", content: systemPrompt),
                    GroqMessage(role: "user", content: userText)
                ],
                responseFormat: ResponseFormat(type: "json_object")
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw HTTPErrorMapper.map(urlError: error)
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }

        #if DEBUG
        if logBodies, let text = String(data: data, encoding: .utf8) {
            print("MeetRecap proxy response: \(text)")
        }
        #endif

        guard let http = response as? HTTPURLResponse else {
            throw AppError.invalidResponse("missing status")
        }
        guard (200..<300).contains(http.statusCode) else {
            let details = String(data: data, encoding: .utf8) ?? ""
            throw HTTPErrorMapper.map(status: http.statusCode, details: details)
        }

        let decoded = try JSONDecoder().decode(GroqResponseBody.self, from: data)
        let content = decoded.choices.first?.message?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if content.isEmpty {
            throw AppError.invalidResponse("empty response")
        }
        return content
    }
}

enum ProxyConfig {
    static var baseURL: URL {
        var raw = Bundle.main.object(forInfoDictionaryKey: "PROXY_BASE_URL") as? String
            ?? "https://example.workers.dev/"
        raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.hasSuffix("/") {
            raw += "/"
        }
        return URL(string: raw) ?? URL(string: "https://example.workers.dev/")!
    }
}

private struct GroqRequestBody: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [GroqMessage]
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case responseFormat = "response_format"
    }
}

private struct GroqMessage: Codable {
    let role: String
    let content: String
}

private struct ResponseFormat: Encodable {
    let type: String
}

private struct GroqResponseBody: Decodable {
    let choices: [GroqChoice]
}

private struct GroqChoice: Decodable {
    let message: GroqResponseMessage?
}

private struct GroqResponseMessage: Decodable {
    let content: String?
}
