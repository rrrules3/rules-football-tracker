//
//  Fixture.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation

// MARK: - API-Football Response Wrapper

nonisolated struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    let get: String
    let results: Int
    let response: [T]
}

// MARK: - Fixture Response

nonisolated struct FixtureResponse: Codable, Sendable {
    let fixture: FixtureInfo
    let league: LeagueInfo
    let teams: TeamsInfo
    let goals: Goals
    let score: Score
}

nonisolated struct FixtureInfo: Codable, Sendable {
    let id: Int
    let date: String
    let timestamp: Int
    let status: FixtureStatus
    let referee: String?
    let venue: FixtureVenue?
}

nonisolated struct FixtureVenue: Codable, Sendable {
    let id: Int?
    let name: String?
    let city: String?
}

nonisolated struct FixtureStatus: Codable, Sendable {
    let long: String
    let short: String    // 1H, 2H, HT, FT, NS, etc.
    let elapsed: Int?
    let extra: Int?      // added/stoppage time minutes (nil if none)
}

nonisolated struct LeagueInfo: Codable, Sendable {
    let id: Int
    let name: String
    let country: String
    let logo: String
    let flag: String?   // country flag URL (e.g. SVG from api-sports CDN)
    let round: String?
}

nonisolated struct TeamsInfo: Codable, Sendable {
    let home: TeamInfo
    let away: TeamInfo
}

nonisolated struct TeamInfo: Codable, Sendable {
    let id: Int
    let name: String
    let logo: String
    let winner: Bool?
    let national: Bool?
}

nonisolated struct Goals: Codable, Sendable {
    let home: Int?
    let away: Int?
}

nonisolated struct Score: Codable, Sendable {
    let halftime: Goals
    let fulltime: Goals
    let penalty: Goals?   // nil unless match went to a penalty shootout
}

// MARK: - Statistics Response

nonisolated struct StatisticsResponse: Codable, Sendable {
    let team: TeamInfo
    let statistics: [StatItem]
}

nonisolated struct StatItem: Codable, Sendable {
    let type: String
    let value: StatValue
}

nonisolated enum StatValue: Codable, Sendable {
    case int(Int)
    case string(String)
    case none

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            self = .none
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let val): try container.encode(val)
        case .string(let val): try container.encode(val)
        case .none: try container.encodeNil()
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let val): return val
        case .string(let str): return Int(str.replacingOccurrences(of: "%", with: ""))
        case .none: return nil
        }
    }
}

// MARK: - Lineups Response

nonisolated struct LineupsResponse: Codable, Sendable {
    let team: TeamInfo
    let formation: String?
    let startXI: [PlayerWrapper]
    let substitutes: [PlayerWrapper]
    let coach: CoachInfo?
}

nonisolated struct PlayerWrapper: Codable, Sendable {
    let player: LineupPlayer
}

nonisolated struct LineupPlayer: Codable, Sendable, Identifiable {
    let id: Int?
    let name: String
    let number: Int?
    let pos: String?       // "G", "D", "M", "F"
    let grid: String?      // "1:1", "2:3" etc — row:col on pitch
}

nonisolated struct CoachInfo: Codable, Sendable {
    let id: Int?
    let name: String
    let photo: String?
}

// MARK: - Events Response

nonisolated struct EventResponse: Codable, Sendable {
    let time: EventTime
    let team: TeamInfo
    let player: EventPlayer
    let assist: EventPlayer?
    let type: String           // "Goal", "Card", "subst", "Var"
    let detail: String         // "Normal Goal", "Penalty", "Own Goal", "Yellow Card", "Red Card"
    let comments: String?
}

nonisolated struct EventTime: Codable, Sendable {
    let elapsed: Int?
    let extra: Int?            // added time (e.g. 90+3 → elapsed=90, extra=3)
}

nonisolated struct EventPlayer: Codable, Sendable {
    let id: Int?
    let name: String?
}

// MARK: - Team Search Response

nonisolated struct TeamSearchResponse: Codable, Sendable {
    let team: TeamInfo
    let venue: Venue?
}

nonisolated struct Venue: Codable, Sendable {
    let name: String?
    let city: String?
}

// MARK: - League Search Response

nonisolated struct LeagueSearchResponse: Codable, Sendable {
    let league: LeagueDetail
    let country: CountryInfo
}

nonisolated struct LeagueDetail: Codable, Sendable {
    let id: Int
    let name: String
    let type: String
    let logo: String
}

nonisolated struct CountryInfo: Codable, Sendable {
    let name: String
    let code: String?
    let flag: String?
}

// MARK: - Player Stats Response (/fixtures/players)

nonisolated struct FixturePlayerTeam: Codable, Sendable {
    let team: TeamInfo
    let players: [FixturePlayerEntry]
}

nonisolated struct FixturePlayerEntry: Codable, Sendable {
    let player: PlayerBasicInfo
    let statistics: [PlayerMatchStats]
}

nonisolated struct PlayerBasicInfo: Codable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct PlayerMatchStats: Codable, Sendable {
    let games: PlayerGameStats
}

nonisolated struct PlayerGameStats: Codable, Sendable {
    let minutes: Int?
    let rating: String?     // e.g. "7.5", may be null
    let captain: Bool?
}
