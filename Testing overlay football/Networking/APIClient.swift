//
//  APIClient.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation

nonisolated enum APIError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case rateLimitExhausted

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key found. Please set your API key in Settings."
        case .invalidResponse: return "Invalid response from server."
        case .httpError(let code): return "HTTP error: \(code)"
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .rateLimitExhausted: return "Daily API request limit reached. Resets at midnight."
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Core Request

    // Shared secret sent with every request so the server can reject
    // anything that didn't come from this app.
    // Value is injected from Secrets.local.xcconfig → Info.plist at build time.
    // Must match APP_SECRET in the server's .env file.
    private let appSecret: String = {
        Bundle.main.object(forInfoDictionaryKey: "APP_SECRET") as? String ?? ""
    }()

    private func request<T: Codable & Sendable>(url: URL) async throws -> APIResponse<T> {
        var urlRequest = URLRequest(url: url)
        urlRequest.addValue(appSecret, forHTTPHeaderField: "x-app-secret")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoded: APIResponse<T>
        do {
            decoded = try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }

        // Record every successful API call in one place so all views
        // (Standings, Season Stats, Knockout, etc.) are counted correctly.
        await RateLimiter.shared.recordRequest()
        return decoded
    }

    // MARK: - Fixtures

    func fetchLiveFixtures() async throws -> [FixtureResponse] {
        let response: APIResponse<FixtureResponse> = try await request(url: APIEndpoints.liveFixtures())
        return response.response
    }

    func fetchLeagueFixturesToday(leagueID: Int) async throws -> [FixtureResponse] {
        let response: APIResponse<FixtureResponse> = try await request(url: APIEndpoints.leagueFixturesToday(leagueID: leagueID))
        return response.response
    }

    func fetchFixturesByDate(_ date: String) async throws -> [FixtureResponse] {
        let response: APIResponse<FixtureResponse> = try await request(url: APIEndpoints.fixturesByDate(date))
        return response.response
    }

    // MARK: - Statistics

    func fetchStatistics(fixtureID: Int) async throws -> [StatisticsResponse] {
        let response: APIResponse<StatisticsResponse> = try await request(url: APIEndpoints.fixtureStatistics(fixtureID: fixtureID))
        return response.response
    }

    // MARK: - Events

    func fetchEvents(fixtureID: Int) async throws -> [EventResponse] {
        let response: APIResponse<EventResponse> = try await request(url: APIEndpoints.fixtureEvents(fixtureID: fixtureID))
        return response.response
    }

    // MARK: - Lineups

    func fetchLineups(fixtureID: Int) async throws -> [LineupsResponse] {
        let response: APIResponse<LineupsResponse> = try await request(url: APIEndpoints.fixtureLineups(fixtureID: fixtureID))
        return response.response
    }

    // MARK: - Player Stats

    func fetchPlayerStats(fixtureID: Int) async throws -> [FixturePlayerTeam] {
        let response: APIResponse<FixturePlayerTeam> = try await request(url: APIEndpoints.fixturePlayerStats(fixtureID: fixtureID))
        return response.response
    }

    // MARK: - Rounds & Knockout Fixtures

    func fetchRounds(leagueID: Int, season: Int) async throws -> [String] {
        let response: APIResponse<String> = try await request(url: APIEndpoints.fixtureRounds(leagueID: leagueID, season: season))
        return response.response
    }

    func fetchFixturesByRound(leagueID: Int, season: Int, round: String) async throws -> [FixtureResponse] {
        let response: APIResponse<FixtureResponse> = try await request(url: APIEndpoints.fixturesByRound(leagueID: leagueID, season: season, round: round))
        return response.response
    }

    // MARK: - Standings

    func fetchStandings(leagueID: Int, season: Int) async throws -> [StandingsAPIResponse] {
        let response: APIResponse<StandingsAPIResponse> = try await request(url: APIEndpoints.standings(leagueID: leagueID, season: season))
        return response.response
    }

    // MARK: - Season Stats

    func fetchTopScorers(leagueID: Int, season: Int) async throws -> [TopScorerEntry] {
        let response: APIResponse<TopScorerEntry> = try await request(url: APIEndpoints.topScorers(leagueID: leagueID, season: season))
        return response.response
    }

    func fetchTopAssists(leagueID: Int, season: Int) async throws -> [TopScorerEntry] {
        let response: APIResponse<TopScorerEntry> = try await request(url: APIEndpoints.topAssists(leagueID: leagueID, season: season))
        return response.response
    }

    func fetchTopRatings(leagueID: Int, season: Int) async throws -> [TopScorerEntry] {
        let response: APIResponse<TopScorerEntry> = try await request(url: APIEndpoints.topRatings(leagueID: leagueID, season: season))
        return response.response
    }

    // MARK: - Search

    func searchTeams(query: String) async throws -> [TeamSearchResponse] {
        let response: APIResponse<TeamSearchResponse> = try await request(url: APIEndpoints.searchTeams(query: query))
        return response.response
    }

    func searchLeagues(query: String) async throws -> [LeagueSearchResponse] {
        let response: APIResponse<LeagueSearchResponse> = try await request(url: APIEndpoints.searchLeagues(query: query))
        return response.response
    }
}
