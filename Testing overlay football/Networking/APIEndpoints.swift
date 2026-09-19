//
//  APIEndpoints.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation

nonisolated enum APIEndpoints {
    // Switch between local dev and production by changing this one line.
    // Local:      "http://localhost:3000"
    // Production: "https://your-app.railway.app"
    static let baseURL = "http://localhost:3000"

    private static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    // Fetch all currently live fixtures
    static func liveFixtures() -> URL {
        URL(string: "\(baseURL)/fixtures?live=all")!
    }

    // Today's fixtures for a specific league
    static func leagueFixturesToday(leagueID: Int) -> URL {
        URL(string: "\(baseURL)/fixtures?league=\(leagueID)&date=\(todayString)")!
    }

    // Fixtures for a specific date
    static func fixturesByDate(_ date: String) -> URL {
        URL(string: "\(baseURL)/fixtures?date=\(date)")!
    }

    // Match statistics for a specific fixture
    static func fixtureStatistics(fixtureID: Int) -> URL {
        URL(string: "\(baseURL)/fixtures/statistics?fixture=\(fixtureID)")!
    }

    // Match events (goals, cards, subs) for a specific fixture
    static func fixtureEvents(fixtureID: Int) -> URL {
        URL(string: "\(baseURL)/fixtures/events?fixture=\(fixtureID)")!
    }

    // Match lineups for a specific fixture
    static func fixtureLineups(fixtureID: Int) -> URL {
        URL(string: "\(baseURL)/fixtures/lineups?fixture=\(fixtureID)")!
    }

    // Search teams by name
    static func searchTeams(query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "\(baseURL)/teams?search=\(encoded)")!
    }

    // Search leagues by name
    static func searchLeagues(query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "\(baseURL)/leagues?search=\(encoded)")!
    }

    // Player match stats + ratings for a specific fixture
    static func fixturePlayerStats(fixtureID: Int) -> URL {
        URL(string: "\(baseURL)/fixtures/players?fixture=\(fixtureID)")!
    }

    // All fixture rounds for a league/season (e.g. "Group Stage - 1", "Round of 16")
    static func fixtureRounds(leagueID: Int, season: Int) -> URL {
        URL(string: "\(baseURL)/fixtures/rounds?league=\(leagueID)&season=\(season)")!
    }

    // Fixtures for a specific round within a league/season
    static func fixturesByRound(leagueID: Int, season: Int, round: String) -> URL {
        let encoded = round.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? round
        return URL(string: "\(baseURL)/fixtures?league=\(leagueID)&season=\(season)&round=\(encoded)")!
    }

    // League standings for a given season
    static func standings(leagueID: Int, season: Int) -> URL {
        URL(string: "\(baseURL)/standings?league=\(leagueID)&season=\(season)")!
    }

    // Top scorers for a league/season
    static func topScorers(leagueID: Int, season: Int) -> URL {
        URL(string: "\(baseURL)/players/topscorers?league=\(leagueID)&season=\(season)")!
    }

    // Top assisters for a league/season
    static func topAssists(leagueID: Int, season: Int) -> URL {
        URL(string: "\(baseURL)/players/topassists?league=\(leagueID)&season=\(season)")!
    }

    // Top rated players for a league/season
    static func topRatings(leagueID: Int, season: Int) -> URL {
        URL(string: "\(baseURL)/players/topratings?league=\(leagueID)&season=\(season)")!
    }

    // Current season year: leagues starting in Aug use previous year (e.g. 2025-26 → 2025).
    // Tournaments mid-year (World Cup 2026) use the current year.
    static var currentSeason: Int {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let month = cal.component(.month, from: Date())
        return month >= 7 ? year : year - 1
    }
}
