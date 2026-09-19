//
//  MatchMonitor.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation
import SwiftData

// Matches grouped under a league header
nonisolated struct LeagueGroup: Identifiable, Sendable {
    let id: Int              // league ID
    let name: String
    let logoURL: String
    let flagURL: String?     // country flag URL
    let country: String
    let matches: [LiveMatch]
}

@MainActor
@Observable
class MatchMonitor {
    // Published state
    var leagueGroups: [LeagueGroup] = []       // today's fixtures grouped by league
    var liveMatches: [LiveMatch] = []
    var isPolling = false
    var lastError: String?
    var requestsRemaining: Int = 100

    /// Timestamp of the most recent successful live fetch — drives the UI countdown.
    var lastLiveFetch: Date = .distantPast

    /// Interval used for the most recent live poll — drives the UI countdown.
    /// Updates dynamically: 60s during active play, 180s during halftime/quiet.
    var liveCacheDuration: TimeInterval = 60

    /// Pre-fetched lineup cache keyed by fixtureID. Populated by scheduled prefetch.
    var lineupCache: [Int: MatchLineups] = [:]

    // Overlay manager reference for pushing live updates
    var overlayManager: OverlayManager?

    // Polling timers / tasks
    private var slowTimer: Timer?               // 30 min — today's fixtures
    private var fastPollingTask: Task<Void, Never>?  // adaptive live poll (1 min active, 3 min HT)
    private var lineupTimer: Timer?             // 60s — checks for upcoming kickoffs
    private var modelContainer: ModelContainer

    // Cache freshness
    private var lastTodayFetch: Date = .distantPast
    private let todayCacheDuration: TimeInterval = 1800   // 30 min
    /// The calendar date (yyyy-MM-dd) of the last successful today-fixtures fetch.
    /// When this differs from the current date, we refresh immediately on the next
    /// timer firing — even if fewer than 30 min have elapsed — so the schedule
    /// automatically rolls over at midnight without needing an app restart.
    private var lastFetchedDateString: String = ""

    // Snapshot of the last live-poll result keyed by fixture ID.
    // Used to detect when a match transitions from live → finished so we can
    // immediately update leagueGroups with the final score before the slow
    // today-fixtures poll refreshes it.
    private var lastKnownLiveMatches: [Int: LiveMatch] = [:]

    // Track fixture IDs where we've already triggered a force-refresh for stale FT status
    // so we don't hammer the API every poll cycle for the same match.
    private var staleRefreshTriggered: Set<Int> = []

    // Track fixtures whose lineups we've already attempted at T-15 min
    private var lineupPrefetchAttempted: Set<Int> = []
    // Track fixtures where the T-15 attempt came back empty (retry at kickoff)
    private var lineupRetryAtKickoff: Set<Int> = []
    // Track fixtures whose kickoff-retry has already happened
    private var lineupKickoffRetried: Set<Int> = []

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Start / Stop

    func startMonitoring() {
        guard !isPolling else { return }
        isPolling = true
        print("📡 MatchMonitor started")

        // Try loading today's fixtures from cache first — saves 1 API call per launch
        if let cached = FixtureCache.loadIfFresh() {
            print("💾 Loaded \(cached.count) fixtures from cache, skipping startup API call")
            rebuildLeagueGroups(from: cached)
            lastTodayFetch = Date()
            lastFetchedDateString = todayDateString()
            // Immediately check for live scores now that league groups are populated
            Task { await fetchLiveFixtures() }
        } else {
            Task {
                await fetchTodayFixtures()
                // Fetch live scores right after so mid-match launches show current scores
                await fetchLiveFixtures()
            }
        }

        // Slow poll for today's matches (every 30 min — catches late postponements)
        slowTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchTodayFixtures()
            }
        }

        // Adaptive live poll — 60s during active play, 180s during halftime or no live matches
        fastPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetchLiveFixtures()

                // Pick next sleep interval based on current match state
                let anyHalftime = self.liveMatches.contains { $0.status.isHalftime }
                let anyLive     = self.liveMatches.contains { $0.status.isLive }
                let interval: TimeInterval = (anyLive && !anyHalftime) ? 60 : 180

                self.liveCacheDuration = interval
                try? await Task.sleep(for: .seconds(interval))
            }
        }

        // Lineup prefetch check every 60s — cheap, only hits API when a match is near kickoff
        lineupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkLineupPrefetch()
            }
        }
    }

    func stopMonitoring() {
        slowTimer?.invalidate()
        slowTimer = nil
        fastPollingTask?.cancel()
        fastPollingTask = nil
        lineupTimer?.invalidate()
        lineupTimer = nil
        isPolling = false
        print("📡 MatchMonitor stopped")
    }

    // MARK: - Fetch Today's Fixtures (single request, filter client-side)

    // League IDs that are always tracked regardless of favorites
    static let priorityLeagueIDs: Set<Int> = [1]  // World Cup

    func fetchTodayFixtures(force: Bool = false) async {
        let today = todayDateString()
        // Refresh immediately if the calendar date has changed (midnight rollover),
        // or if forced (e.g. stale match detected), otherwise respect the 30-min cache window.
        let dateRolled = today != lastFetchedDateString
        guard force || dateRolled || Date().timeIntervalSince(lastTodayFetch) >= todayCacheDuration else { return }

        if dateRolled {
            FixtureCache.clear()   // yesterday's cache is no longer valid
            print("🌅 Date rolled over — clearing fixture cache and refreshing schedule")
        }

        let leagueIDs = Set(getFavoriteLeagueIDs()).union(Self.priorityLeagueIDs)
        let teamIDs = Set(getFavoriteTeamIDs())

        if leagueIDs.isEmpty && teamIDs.isEmpty {
            leagueGroups = []
            return
        }

        guard await RateLimiter.shared.canMakeRequest() else {
            lastError = "API budget low — pausing non-critical polling"
            return
        }

        do {
            // Single API call for all of today's fixtures
            let allFixtures = try await APIClient.shared.fetchFixturesByDate(today)
            await RateLimiter.shared.recordRequest()

            // Persist full payload so the next launch can skip this call
            FixtureCache.save(allFixtures)

            rebuildLeagueGroups(from: allFixtures)
            lastTodayFetch = Date()
            lastFetchedDateString = todayDateString()
            requestsRemaining = await RateLimiter.shared.requestsRemaining
            lastError = nil

            let totalMatches = leagueGroups.reduce(0) { $0 + $1.matches.count }
            print("📅 Fetched \(totalMatches) matches across \(leagueGroups.count) leagues (\(requestsRemaining) API requests left)")

            // Check for upcoming matches and schedule notifications
            let allMatches = leagueGroups.flatMap(\.matches)
            for match in allMatches {
                NotificationManager.shared.schedulePreMatchAlert(for: match)
            }
        } catch {
            lastError = error.localizedDescription
            print("❌ Today fetch error: \(error.localizedDescription)")
        }
    }

    /// Shared logic that turns a decoded fixture list into filtered league groups.
    private func rebuildLeagueGroups(from allFixtures: [FixtureResponse]) {
        let leagueIDs = Set(getFavoriteLeagueIDs()).union(Self.priorityLeagueIDs)
        let teamIDs = Set(getFavoriteTeamIDs())

        let relevant = allFixtures.filter { fixture in
            leagueIDs.contains(fixture.league.id) ||
            teamIDs.contains(fixture.teams.home.id) ||
            teamIDs.contains(fixture.teams.away.id)
        }

        var groupedByLeague: [Int: (league: LeagueInfo, fixtures: [FixtureResponse])] = [:]
        for fixture in relevant {
            let lid = fixture.league.id
            if groupedByLeague[lid] == nil {
                groupedByLeague[lid] = (league: fixture.league, fixtures: [])
            }
            groupedByLeague[lid]!.fixtures.append(fixture)
        }

        leagueGroups = groupedByLeague.map { (_, value) in
            let matches = value.fixtures
                .map { LiveMatch(from: $0) }
                .sorted { $0.kickoffDate < $1.kickoffDate }
            return LeagueGroup(
                id: value.league.id,
                name: value.league.name,
                logoURL: value.league.logo,
                flagURL: value.league.flag,
                country: value.league.country,
                matches: matches
            )
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Fetch Live Fixtures

    func fetchLiveFixtures() async {
        // Skip if nothing tracked is currently in progress or about to be.
        // A match "matters" if its kickoff is within the last 4 hours (so still plausibly live).
        let now = Date()
        let trackedMatches = leagueGroups.flatMap(\.matches)
        let potentiallyLive = trackedMatches.filter { match in
            match.status.isLive ||
            (match.kickoffDate <= now && now.timeIntervalSince(match.kickoffDate) < 4 * 3600 && !match.status.isFinished)
        }

        if potentiallyLive.isEmpty {
            // No tracked game is live or imminent — skip the call entirely.
            liveMatches = []
            return
        }

        let leagueIDs = Set(getFavoriteLeagueIDs()).union(Self.priorityLeagueIDs)
        let teamIDs = Set(getFavoriteTeamIDs())

        if leagueIDs.isEmpty && teamIDs.isEmpty {
            liveMatches = []
            return
        }

        guard await RateLimiter.shared.canMakeRequest(critical: true) else {
            lastError = "API budget exhausted for today"
            return
        }

        do {
            let allLive = try await APIClient.shared.fetchLiveFixtures()

            // Filter to only matches involving favorited teams or leagues
            let relevant = allLive.filter { fixture in
                teamIDs.contains(fixture.teams.home.id) ||
                teamIDs.contains(fixture.teams.away.id) ||
                leagueIDs.contains(fixture.league.id)
            }

            // Detect goals by comparing with previous state
            let previousScores = Dictionary(uniqueKeysWithValues: liveMatches.map { ($0.id, ($0.homeScore, $0.awayScore)) })

            liveMatches = relevant.map { fixture in
                let match = LiveMatch(from: fixture)
                if let prev = previousScores[match.id] {
                    if match.homeScore > prev.0 {
                        print("⚽ GOAL! \(match.homeTeam.name) scores! \(match.homeScore)-\(match.awayScore)")
                        NotificationManager.shared.sendGoalNotification(match: match, scoringTeamName: match.homeTeam.name)
                    }
                    if match.awayScore > prev.1 {
                        print("⚽ GOAL! \(match.awayTeam.name) scores! \(match.homeScore)-\(match.awayScore)")
                        NotificationManager.shared.sendGoalNotification(match: match, scoringTeamName: match.awayTeam.name)
                    }
                }
                return match
            }

            lastLiveFetch = Date()
            requestsRemaining = await RateLimiter.shared.requestsRemaining
            lastError = nil

            // Detect matches that just transitioned from live → finished.
            // Those are present in lastKnownLiveMatches but absent from the new liveMatches.
            // Immediately stamp them as FT in leagueGroups so they reappear in the
            // Today schedule with the correct final score (before the 30-min slow poll fires).
            let newLiveIDs = Set(liveMatches.map(\.id))
            for (matchID, endedMatch) in lastKnownLiveMatches where !newLiveIDs.contains(matchID) {
                var ftMatch = endedMatch
                ftMatch.status = .finished
                updateMatchInGroups(id: matchID, with: ftMatch)
                print("✅ Match \(matchID) (\(endedMatch.homeTeam.name) \(endedMatch.homeScore)-\(endedMatch.awayScore) \(endedMatch.awayTeam.name)) moved to FT in Today schedule")
            }
            lastKnownLiveMatches = Dictionary(uniqueKeysWithValues: liveMatches.map { ($0.id, $0) })

            // Push updates to any open overlays
            for match in liveMatches {
                overlayManager?.updateOverlay(with: match)
            }

            // Catch matches that finished without ever being tracked as live
            // (app launched after kickoff, or live poll was skipped).
            // If a match's kickoff was >110 min ago but it still shows as NS/TBD,
            // it has almost certainly finished — force a today refresh to get the real score.
            let staleMatches = leagueGroups.flatMap(\.matches).filter { match in
                let elapsed = now.timeIntervalSince(match.kickoffDate)
                return elapsed > 110 * 60
                    && !match.status.isFinished
                    && !match.status.isLive
                    && match.status != .postponed
                    && match.status != .cancelled
                    && match.status != .abandoned
                    && !staleRefreshTriggered.contains(match.id)
            }
            if !staleMatches.isEmpty {
                staleMatches.forEach { staleRefreshTriggered.insert($0.id) }
                print("🔄 \(staleMatches.count) match(es) overdue for FT — force-refreshing today's fixtures")
                await fetchTodayFixtures(force: true)
            }

            if !liveMatches.isEmpty {
                print("🔴 \(liveMatches.count) live matches tracked (\(requestsRemaining) API requests left)")
            }
        } catch {
            lastError = error.localizedDescription
            print("❌ Live fetch error: \(error.localizedDescription)")
        }
    }

    // MARK: - Lineup Prefetch (Option B: fetch at T-15 min, retry at kickoff if empty)

    /// Runs every 60s. Checks if any favorited match is near kickoff and fetches
    /// lineups once they should be available.
    func checkLineupPrefetch() async {
        let now = Date()
        let allMatches = leagueGroups.flatMap(\.matches)

        for match in allMatches {
            let secondsUntilKickoff = match.kickoffDate.timeIntervalSince(now)

            // T-15 min window: fetch once if not yet attempted
            if secondsUntilKickoff <= 15 * 60 && secondsUntilKickoff > 0 &&
               !lineupPrefetchAttempted.contains(match.id) {
                lineupPrefetchAttempted.insert(match.id)
                await prefetchLineups(for: match.id, isRetry: false)
            }

            // Kickoff retry: if the T-15 attempt came back empty, try again at kickoff
            if secondsUntilKickoff <= 0 && secondsUntilKickoff > -120 &&
               lineupRetryAtKickoff.contains(match.id) &&
               !lineupKickoffRetried.contains(match.id) {
                lineupKickoffRetried.insert(match.id)
                await prefetchLineups(for: match.id, isRetry: true)
            }
        }
    }

    private func prefetchLineups(for fixtureID: Int, isRetry: Bool) async {
        // Skip if already cached
        if lineupCache[fixtureID] != nil {
            lineupRetryAtKickoff.remove(fixtureID)
            return
        }

        guard await RateLimiter.shared.canMakeRequest() else { return }

        do {
            let lineups = try await APIClient.shared.fetchLineups(fixtureID: fixtureID)
            requestsRemaining = await RateLimiter.shared.requestsRemaining

            guard lineups.count >= 2 else {
                // Empty response — mark for retry at kickoff if this was the T-15 attempt
                if !isRetry {
                    lineupRetryAtKickoff.insert(fixtureID)
                    print("⏳ Lineups not ready for fixture \(fixtureID) at T-15 — will retry at kickoff")
                }
                return
            }

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

            lineupCache[fixtureID] = MatchLineups(home: homeLineup, away: awayLineup)
            lineupRetryAtKickoff.remove(fixtureID)

            // Push into any already-open overlay for this fixture
            overlayManager?.applyPrefetchedLineups(fixtureID: fixtureID)

            print("📋 Prefetched lineups for fixture \(fixtureID) (\(isRetry ? "kickoff retry" : "T-15"))")
        } catch {
            print("❌ Lineup prefetch error for \(fixtureID): \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func getFavoriteLeagueIDs() -> [Int] {
        let context = ModelContext(modelContainer)
        let leagues = (try? context.fetch(FetchDescriptor<FavoriteLeague>())) ?? []
        return leagues.map(\.id)
    }

    private func getFavoriteTeamIDs() -> [Int] {
        let context = ModelContext(modelContainer)
        let teams = (try? context.fetch(FetchDescriptor<FavoriteTeam>())) ?? []
        return teams.map(\.id)
    }

    // MARK: - Force Refresh (used by retry / pull-to-refresh)

    /// Clears all caches and immediately re-fetches today's fixtures and live scores.
    /// Safe to call from any SwiftUI `.refreshable` or retry button.
    func forceRefresh() async {
        FixtureCache.clear()
        lastTodayFetch = .distantPast
        lastFetchedDateString = ""
        lastError = nil
        await fetchTodayFixtures()
        await fetchLiveFixtures()
    }

    /// Replaces a single match entry inside `leagueGroups` without a full rebuild.
    private func updateMatchInGroups(id: Int, with updatedMatch: LiveMatch) {
        leagueGroups = leagueGroups.map { group in
            guard group.matches.contains(where: { $0.id == id }) else { return group }
            return LeagueGroup(
                id: group.id,
                name: group.name,
                logoURL: group.logoURL,
                flagURL: group.flagURL,
                country: group.country,
                matches: group.matches.map { $0.id == id ? updatedMatch : $0 }
            )
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
