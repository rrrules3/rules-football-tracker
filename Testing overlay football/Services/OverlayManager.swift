//
//  OverlayManager.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import AppKit
import SwiftUI

@MainActor
@Observable
class OverlayManager {
    static let maxOverlays = 3

    private(set) var activeOverlays: [Int: OverlayEntry] = [:]  // fixtureID -> entry

    // UserDefaults keys for persisting the last-used overlay position
    private let savedXKey = "overlay.lastX"
    private let savedYKey = "overlay.lastY"

    /// Set by AppDelegate so we can read prefetched lineups + HT pause state.
    weak var matchMonitor: MatchMonitor?

    enum GoalSide: Sendable {
        case home, away
    }

    struct GoalEvent {
        let side: GoalSide
        let teamName: String
        let teamColor: Color
        let score: String
    }

    struct VAREvent {
        let teamName: String
        let teamColor: Color
        let scorerName: String?   // player whose goal was rescinded (nil if not yet known)
        let score: String         // corrected score after rescission
    }

    // How often to re-fetch stats vs events during a live match (separate cadences)
    static let eventsPollInterval: TimeInterval = 180   // 3 min — goals/cards are time-sensitive
    static let statsPollInterval: TimeInterval  = 600   // 10 min — possession/shots change slowly

    struct OverlayEntry {
        let panel: NSPanel
        let fixtureID: Int
        var match: LiveMatch
        var isExpanded: Bool = false
        var goalEvent: GoalEvent? = nil
        var varEvent: VAREvent? = nil
        var homeTeamColor: Color = .blue
        var awayTeamColor: Color = .red
        var finishedAt: Date? = nil          // when the match ended, for auto-close timer
        var lastStatsFetch: Date = .distantPast   // throttle for stats endpoint
        var lastEventsFetch: Date = .distantPast  // throttle for events endpoint
        var eventsFinalised: Bool = false     // true once fetched after FT — no more refetching
    }

    var activeMatches: [LiveMatch] {
        activeOverlays.values.map(\.match).sorted { $0.id < $1.id }
    }

    var canOpenMore: Bool {
        activeOverlays.count < Self.maxOverlays
    }

    // MARK: - Open Overlay

    func openOverlay(for match: LiveMatch) {
        // Don't open duplicate
        guard activeOverlays[match.id] == nil else {
            bringToFront(fixtureID: match.id)
            return
        }

        guard canOpenMore else {
            print("⚠️ Max overlays reached (\(Self.maxOverlays))")
            return
        }

        // Calculate position
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let overlayWidth  = OverlayView.collapsedWidth
        let overlayHeight = OverlayView.collapsedHeightForEvents(match.events.count)
        let offset = CGFloat(activeOverlays.count) * 30

        // First overlay: restore last saved position if available; otherwise default to top-right.
        // Additional overlays always stack with an offset from the first.
        let x: CGFloat
        let y: CGFloat
        if activeOverlays.isEmpty,
           let sx = UserDefaults.standard.object(forKey: savedXKey) as? Double,
           let sy = UserDefaults.standard.object(forKey: savedYKey) as? Double {
            x = CGFloat(sx)
            y = CGFloat(sy)
        } else {
            x = screenFrame.maxX - overlayWidth  - 20 - offset
            y = screenFrame.maxY - overlayHeight - 20 - offset
        }

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: overlayWidth, height: overlayHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let entry = OverlayEntry(
            panel: panel,
            fixtureID: match.id,
            match: match,
            isExpanded: false
        )
        activeOverlays[match.id] = entry

        rebuildOverlayContent(fixtureID: match.id)
        panel.orderFrontRegardless()

        // Sample team colors from crests for the possession bar
        let homeLogoURL = match.homeTeam.logo
        let awayLogoURL = match.awayTeam.logo
        Task {
            let color = await ColorSampler.shared.dominantColor(from: homeLogoURL)
            guard var freshEntry = activeOverlays[match.id] else { return }
            freshEntry.homeTeamColor = color
            activeOverlays[match.id] = freshEntry
            rebuildOverlayContent(fixtureID: match.id)
        }
        Task {
            let color = await ColorSampler.shared.dominantColor(from: awayLogoURL)
            guard var freshEntry = activeOverlays[match.id] else { return }
            freshEntry.awayTeamColor = color
            activeOverlays[match.id] = freshEntry
            rebuildOverlayContent(fixtureID: match.id)
        }

        // If MatchMonitor already prefetched lineups for this fixture, apply them now (free)
        applyPrefetchedLineups(fixtureID: match.id)

        // Fetch stats on open — possession bar + SOG show in the collapsed view.
        // Events are not shown collapsed, so skip them here; they load on first expand
        // or immediately if a goal is detected by updateOverlay.
        if match.status.isLive || match.status.isFinished {
            fetchStats(for: match.id)
        }

        print("🪟 Opened overlay for \(match.homeTeam.name) vs \(match.awayTeam.name)")
    }

    /// Called by MatchMonitor (or openOverlay) when prefetched lineups become available.
    /// Pulls lineups from the monitor's cache into the overlay entry without an API call.
    func applyPrefetchedLineups(fixtureID: Int) {
        guard var entry = activeOverlays[fixtureID],
              entry.match.lineups == nil,
              let cached = matchMonitor?.lineupCache[fixtureID] else { return }
        entry.match.lineups = cached
        activeOverlays[fixtureID] = entry
        rebuildOverlayContent(fixtureID: fixtureID)
    }

    // MARK: - Toggle Expand

    func toggleExpand(fixtureID: Int) {
        guard var entry = activeOverlays[fixtureID] else { return }

        entry.isExpanded.toggle()
        activeOverlays[fixtureID] = entry

        // Fetch stats, events, lineups, and player ratings when expanding
        if entry.isExpanded {
            let force = entry.match.status.isFinished
            fetchStats(for: fixtureID, force: force)
            fetchEvents(for: fixtureID, force: force)
            fetchLineups(for: fixtureID)
            fetchPlayerRatings(for: fixtureID)
        }

        // Resize the panel
        let newWidth = entry.isExpanded ? OverlayView.expandedWidth : OverlayView.collapsedWidth
        let newHeight = entry.isExpanded ? OverlayView.expandedHeight : OverlayView.collapsedHeightForEvents(entry.match.events.count)

        var frame = entry.panel.frame
        let heightDiff = newHeight - frame.size.height
        frame.origin.y -= heightDiff  // grow downward from top
        frame.size.width = newWidth
        frame.size.height = newHeight
        entry.panel.setFrame(frame, display: true, animate: true)

        rebuildOverlayContent(fixtureID: fixtureID)
    }

    // MARK: - Fetch Statistics

    private func fetchStats(for fixtureID: Int, force: Bool = false) {
        Task {
            guard let entry = activeOverlays[fixtureID] else { return }

            // Halftime pause: nothing changes during the break, so don't burn calls
            if !force && entry.match.status.isHalftime { return }

            // Throttle: stats change slowly — skip if fetched within the last 10 min
            if !force && Date().timeIntervalSince(entry.lastStatsFetch) < Self.statsPollInterval {
                return
            }

            guard await RateLimiter.shared.canMakeRequest() else { return }

            do {
                let stats = try await APIClient.shared.fetchStatistics(fixtureID: fixtureID)
                guard stats.count >= 2 else { return }

                // Re-read entry AFTER the await — another task may have updated it
                guard var freshEntry = activeOverlays[fixtureID] else { return }

                let homeStats = stats[0].statistics
                let awayStats = stats[1].statistics

                func findStat(_ name: String, in items: [StatItem]) -> Int? {
                    items.first { $0.type == name }?.value.intValue
                }

                if let homePoss = findStat("Ball Possession", in: homeStats),
                   let awayPoss = findStat("Ball Possession", in: awayStats) {
                    freshEntry.match.possession = StatPair(home: homePoss, away: awayPoss)
                    freshEntry.match.teamInPossession = homePoss >= awayPoss ? true : false
                }

                if let homeShots = findStat("Shots on Goal", in: homeStats),
                   let awayShots = findStat("Shots on Goal", in: awayStats) {
                    freshEntry.match.shotsOnTarget = StatPair(home: homeShots, away: awayShots)
                }

                if let homeTotal = findStat("Total Shots", in: homeStats),
                   let awayTotal = findStat("Total Shots", in: awayStats) {
                    freshEntry.match.totalShots = StatPair(home: homeTotal, away: awayTotal)
                }

                if let homeCorners = findStat("Corner Kicks", in: homeStats),
                   let awayCorners = findStat("Corner Kicks", in: awayStats) {
                    freshEntry.match.corners = StatPair(home: homeCorners, away: awayCorners)
                }

                if let homeFouls = findStat("Fouls", in: homeStats),
                   let awayFouls = findStat("Fouls", in: awayStats) {
                    freshEntry.match.fouls = StatPair(home: homeFouls, away: awayFouls)
                }

                if let homeYellow = findStat("Yellow Cards", in: homeStats),
                   let awayYellow = findStat("Yellow Cards", in: awayStats) {
                    freshEntry.match.yellowCards = StatPair(home: homeYellow, away: awayYellow)
                }

                if let homeRed = findStat("Red Cards", in: homeStats),
                   let awayRed = findStat("Red Cards", in: awayStats) {
                    freshEntry.match.redCards = StatPair(home: homeRed, away: awayRed)
                }

                if let homeSaves = findStat("Goalkeeper Saves", in: homeStats),
                   let awaySaves = findStat("Goalkeeper Saves", in: awayStats) {
                    freshEntry.match.saves = StatPair(home: homeSaves, away: awaySaves)
                }

                if let homeOff = findStat("Offsides", in: homeStats),
                   let awayOff = findStat("Offsides", in: awayStats) {
                    freshEntry.match.offsides = StatPair(home: homeOff, away: awayOff)
                }

                // xG — stored as a string like "1.45" in the stat value
                let homeXG = homeStats.first { $0.type == "expected_goals" }.flatMap {
                    if case .string(let s) = $0.value { return s } else { return nil }
                }
                let awayXG = awayStats.first { $0.type == "expected_goals" }.flatMap {
                    if case .string(let s) = $0.value { return s } else { return nil }
                }
                if let hx = homeXG, let ax = awayXG {
                    freshEntry.match.xG = (home: hx, away: ax)
                }

                freshEntry.lastStatsFetch = Date()
                activeOverlays[fixtureID] = freshEntry
                rebuildOverlayContent(fixtureID: fixtureID)

                print("📊 Stats loaded for fixture \(fixtureID)")
            } catch {
                print("❌ Stats fetch error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fetch Player Ratings

    private func fetchPlayerRatings(for fixtureID: Int) {
        Task {
            guard let entry = activeOverlays[fixtureID] else { return }
            // Only fetch once per match — ratings don't change mid-game (only finalized at FT)
            guard entry.match.playerRatings.isEmpty || entry.match.status.isFinished else { return }

            guard await RateLimiter.shared.canMakeRequest() else { return }

            do {
                let teams = try await APIClient.shared.fetchPlayerStats(fixtureID: fixtureID)

                // Build playerID → rating / captain / minutes dictionaries
                var ratings: [Int: Double] = [:]
                var captainIDs: Set<Int> = []
                var playerMinutes: [Int: Int] = [:]

                for team in teams {
                    for playerEntry in team.players {
                        let pid = playerEntry.player.id
                        if let ratingStr = playerEntry.statistics.first?.games.rating,
                           let rating = Double(ratingStr) {
                            ratings[pid] = rating
                        }
                        if playerEntry.statistics.first?.games.captain == true {
                            captainIDs.insert(pid)
                        }
                        if let mins = playerEntry.statistics.first?.games.minutes {
                            playerMinutes[pid] = mins
                        }
                    }
                }

                guard !ratings.isEmpty else { return }
                guard var freshEntry = activeOverlays[fixtureID] else { return }
                freshEntry.match.playerRatings = ratings
                freshEntry.match.captainIDs = captainIDs
                freshEntry.match.playerMinutes = playerMinutes
                activeOverlays[fixtureID] = freshEntry
                rebuildOverlayContent(fixtureID: fixtureID)

                print("⭐ Player ratings loaded for fixture \(fixtureID): \(ratings.count) players")
            } catch {
                print("❌ Player ratings fetch error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fetch Lineups

    private func fetchLineups(for fixtureID: Int) {
        // First try the prefetch cache — free, no API call
        applyPrefetchedLineups(fixtureID: fixtureID)

        Task {
            guard let entry = activeOverlays[fixtureID] else { return }
            // Don't re-fetch if we already have lineups
            guard entry.match.lineups == nil else { return }

            guard await RateLimiter.shared.canMakeRequest() else { return }

            do {
                let lineups = try await APIClient.shared.fetchLineups(fixtureID: fixtureID)
                guard lineups.count >= 2 else { return }

                // Re-read entry AFTER the await — another task may have updated it
                guard var freshEntry = activeOverlays[fixtureID] else { return }
                guard freshEntry.match.lineups == nil else { return }

                let homeLineup = TeamLineup(
                    formation: lineups[0].formation ?? "N/A",
                    startingXI: lineups[0].startXI.map(\.player),
                    substitutes: lineups[0].substitutes.map(\.player),
                    coachName: lineups[0].coach?.name
                )
                let awayLineup = TeamLineup(
                    formation: lineups[1].formation ?? "N/A",
                    startingXI: lineups[1].startXI.map(\.player),
                    substitutes: lineups[1].substitutes.map(\.player),
                    coachName: lineups[1].coach?.name
                )

                let merged = MatchLineups(home: homeLineup, away: awayLineup)
                freshEntry.match.lineups = merged
                activeOverlays[fixtureID] = freshEntry
                matchMonitor?.lineupCache[fixtureID] = merged
                rebuildOverlayContent(fixtureID: fixtureID)

                print("📋 Lineups loaded for fixture \(fixtureID)")
            } catch {
                print("❌ Lineups fetch error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fetch Events (goals + red cards)

    private func fetchEvents(for fixtureID: Int, force: Bool = false) {
        Task {
            guard let entry = activeOverlays[fixtureID] else { return }

            // Don't re-fetch events for finished matches once we have them
            if entry.eventsFinalised { return }

            // Halftime pause: no new events during the break
            if !force && entry.match.status.isHalftime { return }

            // Throttle: events are time-sensitive (goals/cards) — re-fetch every 3 min
            if !force && !entry.match.events.isEmpty &&
               Date().timeIntervalSince(entry.lastEventsFetch) < Self.eventsPollInterval {
                return
            }

            guard await RateLimiter.shared.canMakeRequest() else { return }

            do {
                let events = try await APIClient.shared.fetchEvents(fixtureID: fixtureID)

                // Identify penalty shootout minutes — any "Miss" event is exclusively PSO.
                // "Goal"/"Penalty" events at the same elapsed minute are also PSO kicks.
                let psoMinutes = Set(events.filter { $0.type == "Miss" }.compactMap { $0.time.elapsed })

                // Parse all events into timeline events (goals/cards), substitutions, and PSO kicks
                var matchEvents: [MatchEvent] = []
                var matchSubs: [MatchEvent] = []
                var shootoutEvents: [MatchEvent] = []

                for event in events {
                    guard let elapsed = event.time.elapsed else { continue }
                    let extra = event.time.extra ?? 0
                    let minute = extra > 0 ? "\(elapsed)+\(extra)'" : "\(elapsed)'"
                    let playerName = event.player.name ?? "Unknown"
                    let playerID = event.player.id
                    let assistName = event.assist?.name
                    let assistID = event.assist?.id

                    switch event.type {
                    case "Miss":
                        // Distinguish saved vs missed via the comments field
                        let psoMissType: MatchEventType = event.comments == "Saved" ? .penaltyShootoutSaved : .penaltyShootoutMissed
                        shootoutEvents.append(MatchEvent(
                            id: "\(fixtureID)_pso_miss_\(minute)_\(playerName)",
                            minute: minute,
                            playerName: playerName,
                            playerID: playerID,
                            assistName: nil,
                            assistID: nil,
                            teamID: event.team.id,
                            type: psoMissType
                        ))
                    case "Goal":
                        // Check if this is a PSO scored kick or a regular match goal/penalty
                        if event.detail == "Penalty" && psoMinutes.contains(elapsed) {
                            shootoutEvents.append(MatchEvent(
                                id: "\(fixtureID)_pso_scored_\(minute)_\(playerName)",
                                minute: minute,
                                playerName: playerName,
                                playerID: playerID,
                                assistName: nil,
                                assistID: nil,
                                teamID: event.team.id,
                                type: .penaltyShootoutScored
                            ))
                        } else {
                            let eventType: MatchEventType
                            switch event.detail {
                            case "Own Goal": eventType = .ownGoal
                            case "Penalty":  eventType = .penalty
                            default:         eventType = .goal
                            }
                            matchEvents.append(MatchEvent(
                                id: "\(fixtureID)_\(minute)_\(playerName)",
                                minute: minute,
                                playerName: playerName,
                                playerID: playerID,
                                assistName: assistName,
                                assistID: assistID,
                                teamID: event.team.id,
                                type: eventType
                            ))
                        }
                    case "Card":
                        let cardType: MatchEventType = event.detail == "Red Card" ? .redCard : .yellowCard
                        matchEvents.append(MatchEvent(
                            id: "\(fixtureID)_\(event.detail)_\(minute)_\(playerName)",
                            minute: minute,
                            playerName: playerName,
                            playerID: playerID,
                            assistName: nil,
                            assistID: nil,
                            teamID: event.team.id,
                            type: cardType
                        ))
                    case "subst":
                        // player = going off, assist = coming on
                        matchSubs.append(MatchEvent(
                            id: "\(fixtureID)_sub_\(minute)_\(playerName)",
                            minute: minute,
                            playerName: playerName,
                            playerID: playerID,
                            assistName: assistName,
                            assistID: assistID,
                            teamID: event.team.id,
                            type: .substitution
                        ))
                    default:
                        break
                    }
                }

                // Re-read entry AFTER the await — another task may have updated it
                guard var freshEntry = activeOverlays[fixtureID] else { return }

                // Diff: find goal/card events that were present before but have now disappeared.
                // These are goals that were rescinded by VAR — preserve them as rescindedEvents
                // so the timeline can still display them with strikethrough.
                let newEventIDs = Set(matchEvents.map(\.id))
                let goalTypes: Set<MatchEventType> = [.goal, .penalty, .ownGoal]
                let newlyRescinded = freshEntry.match.events
                    .filter { goalTypes.contains($0.type) && !newEventIDs.contains($0.id) }
                    .map { event -> MatchEvent in
                        var rescinded = event
                        rescinded.isRescinded = true
                        return rescinded
                    }

                // Accumulate rescinded events (never drop ones we already know about)
                var allRescinded = freshEntry.match.rescindedEvents
                for r in newlyRescinded where !allRescinded.contains(where: { $0.id == r.id }) {
                    allRescinded.append(r)
                }

                freshEntry.match.events = matchEvents
                freshEntry.match.substitutions = matchSubs
                freshEntry.match.rescindedEvents = allRescinded
                freshEntry.match.shootoutEvents = shootoutEvents
                freshEntry.lastEventsFetch = Date()
                if freshEntry.match.status.isFinished {
                    freshEntry.eventsFinalised = true
                }
                activeOverlays[fixtureID] = freshEntry
                rebuildOverlayContent(fixtureID: fixtureID)

                print("📝 Events loaded for fixture \(fixtureID): \(matchEvents.count) goals/reds, \(allRescinded.count) rescinded")
            } catch {
                print("❌ Events fetch error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Update Overlay

    func updateOverlay(with match: LiveMatch) {
        guard var entry = activeOverlays[match.id] else { return }

        let previousHome = entry.match.homeScore
        let previousAway = entry.match.awayScore
        // Capture the current events list BEFORE we overwrite — used to identify the rescinded scorer
        let previousEvents = entry.match.events

        // Preserve stats from previous state
        var updatedMatch = match
        updatedMatch.possession = entry.match.possession ?? match.possession
        updatedMatch.shotsOnTarget = entry.match.shotsOnTarget ?? match.shotsOnTarget
        updatedMatch.yellowCards = entry.match.yellowCards ?? match.yellowCards
        updatedMatch.redCards = entry.match.redCards ?? match.redCards
        updatedMatch.totalShots = entry.match.totalShots ?? match.totalShots
        updatedMatch.corners = entry.match.corners ?? match.corners
        updatedMatch.fouls = entry.match.fouls ?? match.fouls
        updatedMatch.saves = entry.match.saves ?? match.saves
        updatedMatch.offsides = entry.match.offsides ?? match.offsides
        updatedMatch.lineups = entry.match.lineups ?? match.lineups
        updatedMatch.events = entry.match.events.isEmpty ? match.events : entry.match.events
        updatedMatch.substitutions = entry.match.substitutions.isEmpty ? match.substitutions : entry.match.substitutions
        updatedMatch.rescindedEvents = entry.match.rescindedEvents
        updatedMatch.shootoutEvents = entry.match.shootoutEvents
        updatedMatch.penaltyScore = entry.match.penaltyScore ?? match.penaltyScore
        updatedMatch.teamInPossession = entry.match.teamInPossession ?? match.teamInPossession
        updatedMatch.playerRatings = entry.match.playerRatings.isEmpty ? match.playerRatings : entry.match.playerRatings
        updatedMatch.captainIDs = entry.match.captainIDs
        updatedMatch.playerMinutes = entry.match.playerMinutes.isEmpty ? match.playerMinutes : entry.match.playerMinutes
        updatedMatch.xG = entry.match.xG ?? match.xG
        updatedMatch.leagueFlag = entry.match.leagueFlag ?? match.leagueFlag

        entry.match = updatedMatch
        activeOverlays[match.id] = entry

        // Detect goal / VAR rescission and trigger animation
        let goalScored = updatedMatch.homeScore > previousHome || updatedMatch.awayScore > previousAway
        let goalRescinded = updatedMatch.homeScore < previousHome || updatedMatch.awayScore < previousAway

        if updatedMatch.homeScore > previousHome {
            triggerGoal(fixtureID: match.id, side: .home)
        } else if updatedMatch.awayScore > previousAway {
            triggerGoal(fixtureID: match.id, side: .away)
        } else if updatedMatch.homeScore < previousHome {
            triggerVAR(fixtureID: match.id, side: .home, previousEvents: previousEvents)
        } else if updatedMatch.awayScore < previousAway {
            triggerVAR(fixtureID: match.id, side: .away, previousEvents: previousEvents)
        } else {
            rebuildOverlayContent(fixtureID: match.id)
        }

        // On goal or VAR: immediately fetch events so the list reflects reality
        if goalScored || goalRescinded {
            fetchEvents(for: match.id, force: true)
        }

        // Re-fetch stats + events only when expanded and live (throttled to 3 min internally)
        if entry.isExpanded && updatedMatch.status.isLive {
            fetchStats(for: match.id)
            fetchEvents(for: match.id)
        }

        // Auto-close: when match finishes, fetch final data once then schedule close
        if updatedMatch.status.isFinished && entry.finishedAt == nil {
            entry.finishedAt = Date()
            activeOverlays[match.id] = entry

            // One final fetch for complete post-match data
            fetchStats(for: match.id, force: true)
            fetchEvents(for: match.id, force: true)
            fetchLineups(for: match.id)
            rebuildOverlayContent(fixtureID: match.id)

            Task {
                try? await Task.sleep(for: .seconds(300)) // 5 minutes
                closeOverlay(fixtureID: match.id)
            }
            print("⏱️ Match finished — overlay will auto-close in 5 min")
        }
    }

    // MARK: - Goal Animation

    private func triggerGoal(fixtureID: Int, side: GoalSide) {
        guard var entry = activeOverlays[fixtureID] else { return }

        let teamLogo = side == .home ? entry.match.homeTeam.logo : entry.match.awayTeam.logo
        let teamName = side == .home ? entry.match.homeTeam.name : entry.match.awayTeam.name
        let score = "\(entry.match.homeScore) - \(entry.match.awayScore)"

        // Start with a default color, then sample the real one
        entry.goalEvent = GoalEvent(
            side: side,
            teamName: teamName,
            teamColor: side == .home ? .blue : .red,
            score: score
        )
        activeOverlays[fixtureID] = entry
        rebuildOverlayContent(fixtureID: fixtureID)

        // Sample the team color from crest
        Task {
            let color = await ColorSampler.shared.dominantColor(from: teamLogo)
            // Re-read entry after await to avoid clobbering concurrent changes
            guard var freshEntry = activeOverlays[fixtureID] else { return }
            freshEntry.goalEvent = GoalEvent(
                side: side,
                teamName: teamName,
                teamColor: color,
                score: score
            )
            activeOverlays[fixtureID] = freshEntry
            rebuildOverlayContent(fixtureID: fixtureID)
        }

        // Clear the animation after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            // Re-read entry after await to avoid clobbering concurrent changes
            guard var freshEntry = activeOverlays[fixtureID] else { return }
            freshEntry.goalEvent = nil
            activeOverlays[fixtureID] = freshEntry
            rebuildOverlayContent(fixtureID: fixtureID)
        }

        print("🎆 Goal animation triggered for \(teamName)")
    }

    // MARK: - VAR Animation

    private func triggerVAR(fixtureID: Int, side: GoalSide, previousEvents: [MatchEvent]) {
        guard var entry = activeOverlays[fixtureID] else { return }

        let teamID   = side == .home ? entry.match.homeTeam.id   : entry.match.awayTeam.id
        let teamName = side == .home ? entry.match.homeTeam.name : entry.match.awayTeam.name
        let teamLogo = side == .home ? entry.match.homeTeam.logo : entry.match.awayTeam.logo
        let score    = "\(entry.match.homeScore) - \(entry.match.awayScore)"

        // Find the most recently scored goal for the affected team from the previous events snapshot.
        // This is the goal most likely to have been rescinded by VAR.
        let rescindedScorer: String? = previousEvents
            .filter { $0.teamID == teamID && ($0.type == .goal || $0.type == .penalty) }
            .max(by: { minuteSortKey($0.minute) < minuteSortKey($1.minute) })
            .map(\.playerName)

        entry.varEvent = VAREvent(
            teamName: teamName,
            teamColor: side == .home ? .blue : .red,
            scorerName: rescindedScorer,
            score: score
        )
        activeOverlays[fixtureID] = entry
        rebuildOverlayContent(fixtureID: fixtureID)

        // Sample the team's actual color from their crest
        Task {
            let color = await ColorSampler.shared.dominantColor(from: teamLogo)
            guard var freshEntry = activeOverlays[fixtureID] else { return }
            freshEntry.varEvent = VAREvent(
                teamName: teamName,
                teamColor: color,
                scorerName: rescindedScorer,
                score: score
            )
            activeOverlays[fixtureID] = freshEntry
            rebuildOverlayContent(fixtureID: fixtureID)
        }

        // Clear animation after 4 seconds (slightly longer than goal — VAR takes a moment to digest)
        Task {
            try? await Task.sleep(for: .seconds(4))
            guard var freshEntry = activeOverlays[fixtureID] else { return }
            freshEntry.varEvent = nil
            activeOverlays[fixtureID] = freshEntry
            rebuildOverlayContent(fixtureID: fixtureID)
        }

        print("📺 VAR animation triggered — goal rescinded for \(teamName) (scorer: \(rescindedScorer ?? "unknown"))")
    }

    /// Parse "45+3'" → 4503, "45'" → 4500. Same logic as OverlayView.eventSortKey.
    private func minuteSortKey(_ minute: String) -> Int {
        let cleaned = minute.replacingOccurrences(of: "'", with: "")
        let parts = cleaned.split(separator: "+")
        let elapsed = Int(parts.first ?? "0") ?? 0
        let extra   = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return elapsed * 100 + extra
    }

    // MARK: - Close Overlay

    func closeOverlay(fixtureID: Int) {
        guard let entry = activeOverlays.removeValue(forKey: fixtureID) else { return }
        // Persist position so the next overlay opens where the user left it
        let origin = entry.panel.frame.origin
        UserDefaults.standard.set(Double(origin.x), forKey: savedXKey)
        UserDefaults.standard.set(Double(origin.y), forKey: savedYKey)
        entry.panel.close()
        print("🪟 Closed overlay for fixture \(fixtureID)")
    }

    func closeAll() {
        for (_, entry) in activeOverlays {
            entry.panel.close()
        }
        activeOverlays.removeAll()
    }

    // MARK: - Helpers

    private func bringToFront(fixtureID: Int) {
        activeOverlays[fixtureID]?.panel.orderFrontRegardless()
    }

    private func rebuildOverlayContent(fixtureID: Int) {
        guard let entry = activeOverlays[fixtureID] else { return }

        // Compute next live-poll target from MatchMonitor's last fetch + interval
        let nextUpdate: Date? = {
            guard let monitor = matchMonitor, entry.match.status.isLive else { return nil }
            return monitor.lastLiveFetch.addingTimeInterval(monitor.liveCacheDuration)
        }()

        let overlayView = OverlayView(
            match: entry.match,
            isExpanded: entry.isExpanded,
            goalEvent: entry.goalEvent,
            varEvent: entry.varEvent,
            isMatchFinished: entry.finishedAt != nil,
            homeTeamColor: entry.homeTeamColor,
            awayTeamColor: entry.awayTeamColor,
            nextUpdateAt: nextUpdate,
            onClose: { [weak self] in
                self?.closeOverlay(fixtureID: fixtureID)
            },
            onToggleExpand: { [weak self] in
                self?.toggleExpand(fixtureID: fixtureID)
            }
        )

        let includeCountdown = nextUpdate != nil
        let width = entry.isExpanded ? OverlayView.expandedWidth : OverlayView.collapsedWidth
        let height = entry.isExpanded ? OverlayView.expandedHeight : OverlayView.collapsedHeightForEvents(entry.match.events.count, includeCountdown: includeCountdown)

        // Resize panel if content height changed (e.g. events loaded)
        let currentFrame = entry.panel.frame
        if abs(currentFrame.size.height - height) > 1 || abs(currentFrame.size.width - width) > 1 {
            var newFrame = currentFrame
            let heightDiff = height - currentFrame.size.height
            newFrame.origin.y -= heightDiff
            newFrame.size.width = width
            newFrame.size.height = height
            entry.panel.setFrame(newFrame, display: true, animate: true)
        }

        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        entry.panel.contentView = hostingView
    }
}
