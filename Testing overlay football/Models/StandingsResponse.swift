//
//  StandingsResponse.swift
//  Testing overlay football
//

import Foundation

nonisolated struct StandingsAPIResponse: Codable, Sendable {
    let league: StandingsLeagueData
}

nonisolated struct StandingsLeagueData: Codable, Sendable {
    let id: Int
    let name: String
    let logo: String
    let season: Int
    let standings: [[StandingEntry]]
}

nonisolated struct StandingEntry: Codable, Identifiable, Sendable {
    var id: Int { team.id }
    let rank: Int
    let team: StandingTeam
    let points: Int
    let goalsDiff: Int
    let form: String?
    let description: String?
    let group: String?
    let all: StandingRecord
}

nonisolated struct StandingTeam: Codable, Sendable {
    let id: Int
    let name: String
    let logo: String
}

nonisolated struct StandingRecord: Codable, Sendable {
    let played: Int
    let win: Int
    let draw: Int
    let lose: Int
    let goals: StandingGoals
}

nonisolated struct StandingGoals: Codable, Sendable {
    let `for`: Int
    let against: Int
}
