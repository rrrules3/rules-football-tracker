//
//  TopScorersResponse.swift
//  Testing overlay football
//

import Foundation

nonisolated struct TopScorerEntry: Codable, Identifiable, Sendable {
    var id: Int { player.id }
    let player: TopScorerPlayer
    let statistics: [TopScorerStatistics]
}

nonisolated struct TopScorerPlayer: Codable, Sendable {
    let id: Int
    let name: String
    let photo: String?
    let nationality: String?
    let age: Int?
}

nonisolated struct TopScorerStatistics: Codable, Sendable {
    let team: TopScorerTeam
    let league: TopScorerLeague?
    let games: TopScorerGames
    let goals: TopScorerGoals
    let shots: TopScorerShots?
}

nonisolated struct TopScorerLeague: Codable, Sendable {
    let id: Int?
}

nonisolated struct TopScorerTeam: Codable, Sendable {
    let id: Int
    let name: String
    let logo: String
}

nonisolated struct TopScorerGames: Codable, Sendable {
    let appearences: Int?
    let minutes: Int?
    let rating: String?
}

nonisolated struct TopScorerGoals: Codable, Sendable {
    let total: Int?
    let assists: Int?
}

nonisolated struct TopScorerShots: Codable, Sendable {
    let total: Int?
    let on: Int?
}
