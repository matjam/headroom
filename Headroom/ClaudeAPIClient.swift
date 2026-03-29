import Foundation
import WebKit

/// Client for the Claude.ai internal web API.
/// Uses the sessionKey cookie obtained from the login WebView.
actor ClaudeAPIClient {
    private let baseURL = "https://claude.ai"
    private var sessionKey: String?

    func setSessionKey(_ key: String) {
        self.sessionKey = key
    }

    func getSessionKey() -> String? {
        return sessionKey
    }

    // MARK: - Organizations

    func fetchOrganizations() async throws -> [Organization] {
        let data = try await request(path: "/api/organizations")
        let orgs = try JSONDecoder().decode([Organization].self, from: data)
        return orgs
    }

    // MARK: - Usage

    func fetchUsage(orgId: String) async throws -> UsageResponse {
        let data = try await request(path: "/api/organizations/\(orgId)/usage")
        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
        return usage
    }

    // MARK: - Request Helper

    private func request(path: String, method: String = "GET") async throws -> Data {
        guard let sessionKey = sessionKey else {
            throw APIError.notAuthenticated
        }

        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "Referer")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        // Set session cookie
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(statusCode: Int, body: String)
    case cloudflareChallenge

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not logged in. Please sign in to Claude.ai."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .rateLimited:
            return "Too many requests. Try again later."
        case .httpError(let code, let body):
            return "HTTP \(code): \(body.prefix(200))"
        case .cloudflareChallenge:
            return "Blocked by Cloudflare. Please sign in again."
        }
    }
}
