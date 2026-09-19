//
//  LiveMatch.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation

nonisolated enum MatchStatus: String, Sendable {
    case notStarted = "NS"
    case firstHalf = "1H"
    case halftime = "HT"
    case secondHalf = "2H"
    case extraTime = "ET"
    case penalties = "PEN"
    case finished = "FT"
    case finishedAET = "AET"
    case finishedPEN = "FT_PEN"
    case suspended = "SUSP"
    case interrupted = "INT"
    case postponed = "PST"
    case cancelled = "CANC"
    case abandoned = "ABD"
    case unknown = "TBD"

    var isLive: Bool {
        switch self {
        case .firstHalf, .secondHalf, .extraTime, .penalties, .halftime:
            return true
        default:
            return false
        }
    }

    var isFinished: Bool {
        switch self {
        case .finished, .finishedAET, .finishedPEN:
            return true
        default:
            return false
        }
    }

    var isHalftime: Bool {
        self == .halftime
    }

    var displayText: String {
        switch self {
        case .notStarted: return "Not Started"
        case .firstHalf: return "1st Half"
        case .halftime: return "Half Time"
        case .secondHalf: return "2nd Half"
        case .extraTime: return "Extra Time"
        case .penalties: return "Penalties"
        case .finished, .finishedAET, .finishedPEN: return "Full Time"
        case .suspended: return "Suspended"
        case .interrupted: return "Interrupted"
        case .postponed: return "Postponed"
        case .cancelled: return "Cancelled"
        case .abandoned: return "Abandoned"
        case .unknown: return "TBD"
        }
    }

    init(from shortStatus: String) {
        self = MatchStatus(rawValue: shortStatus) ?? .unknown
    }
}

nonisolated struct StatPair: Sendable {
    let home: Int
    let away: Int
}

// MARK: - Lineup Data (per team)

nonisolated struct TeamLineup: Sendable {
    let formation: String          // e.g. "4-2-3-1"
    let startingXI: [LineupPlayer] // 11 starters with grid positions
    let substitutes: [LineupPlayer] // bench players
    let coachName: String?
}

nonisolated struct MatchLineups: Sendable {
    let home: TeamLineup
    let away: TeamLineup
}

// MARK: - Match Event (goal / red card)

nonisolated struct MatchEvent: Identifiable, Sendable {
    let id: String                // unique key
    let minute: String            // e.g. "45'" or "90+3'"
    let playerName: String
    let playerID: Int?            // for matching against lineup players
    let assistName: String?       // name of assisting player (goals only)
    let assistID: Int?
    let teamID: Int
    let type: MatchEventType
    var isRescinded: Bool = false // true when this goal was cancelled by VAR
}

nonisolated enum MatchEventType: Sendable {
    case goal
    case ownGoal
    case penalty
    case redCard
    case yellowCard
    case substitution             // playerName = off, assistName = on
    case penaltyShootoutScored    // PSO — does NOT count as a match goal
    case penaltyShootoutMissed    // PSO miss (wide / over the bar)
    case penaltyShootoutSaved     // PSO miss (goalkeeper save)
}

nonisolated struct LiveMatch: Identifiable, Sendable {
    let id: Int                          // fixture ID
    let homeTeam: TeamInfo
    let awayTeam: TeamInfo
    var homeScore: Int
    var awayScore: Int
    var halftimeHome: Int?               // HT score
    var halftimeAway: Int?
    var elapsed: Int?                    // current clock minute (e.g. 45)
    var extraMinutes: Int?               // added/stoppage time (e.g. 3 → "45+3'")
    var status: MatchStatus
    var leagueID: Int
    var leagueName: String
    var leagueRound: String?             // e.g. "Regular Season - 36"
    var referee: String?
    var venueName: String?
    var venueCity: String?
    var possession: StatPair?
    var shotsOnTarget: StatPair?
    var yellowCards: StatPair?
    var redCards: StatPair?
    var corners: StatPair?
    var fouls: StatPair?
    var totalShots: StatPair?
    var saves: StatPair?
    var offsides: StatPair?
    var xG: (home: String, away: String)?
    var leagueFlag: String?              // country flag URL
    var captainIDs: Set<Int> = []        // player IDs wearing the armband
    var playerMinutes: [Int: Int] = [:]  // playerID → minutes played
    var lineups: MatchLineups?
    var events: [MatchEvent] = []            // goals + cards (shown in timeline)
    var substitutions: [MatchEvent] = []    // subs only (shown in expanded view)
    var rescindedEvents: [MatchEvent] = []  // VAR-cancelled goals — kept for timeline history
    var shootoutEvents: [MatchEvent] = []   // penalty shootout kicks (scored + missed)
    var penaltyScore: StatPair?             // shootout aggregate, e.g. 4-2 (nil if no PSO)
    var teamInPossession: Bool? = nil    // true = home, false = away, nil = unknown
    var playerRatings: [Int: Double] = [:]  // playerID → rating
    var kickoffDate: Date

    /// Formatted clock string, e.g. "45'", "45+3'", or status text when not running.
    var clock: String {
        guard let elapsed = elapsed else { return status.displayText }
        if let extra = extraMinutes, extra > 0 {
            return "\(elapsed)+\(extra)'"
        }
        return "\(elapsed)'"
    }

    init(from fixture: FixtureResponse) {
        self.id = fixture.fixture.id
        self.homeTeam = fixture.teams.home
        self.awayTeam = fixture.teams.away
        self.homeScore = fixture.goals.home ?? 0
        self.awayScore = fixture.goals.away ?? 0
        self.halftimeHome = fixture.score.halftime.home
        self.halftimeAway = fixture.score.halftime.away
        self.status = MatchStatus(from: fixture.fixture.status.short)
        self.leagueID = fixture.league.id
        self.leagueName = fixture.league.name
        self.leagueRound = fixture.league.round
        self.referee = fixture.fixture.referee
        self.venueName = fixture.fixture.venue?.name
        self.venueCity = fixture.fixture.venue?.city
        self.kickoffDate = Date(timeIntervalSince1970: TimeInterval(fixture.fixture.timestamp))
        self.elapsed = fixture.fixture.status.elapsed
        self.extraMinutes = fixture.fixture.status.extra

        self.possession = nil
        self.shotsOnTarget = nil
        self.yellowCards = nil
        self.redCards = nil
        self.corners = nil
        self.fouls = nil
        self.totalShots = nil
        self.saves = nil
        self.offsides = nil
        self.xG = nil
        self.leagueFlag = fixture.league.flag
        self.captainIDs = []
        self.playerMinutes = [:]
        self.lineups = nil
        self.events = []
        self.substitutions = []
        self.rescindedEvents = []
        self.shootoutEvents = []
        if let ph = fixture.score.penalty?.home, let pa = fixture.score.penalty?.away {
            self.penaltyScore = StatPair(home: ph, away: pa)
        } else {
            self.penaltyScore = nil
        }
        self.teamInPossession = nil
        self.playerRatings = [:]
    }
}
