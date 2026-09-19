//
//  OverlayView.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import SwiftUI

struct OverlayView: View {
    var match: LiveMatch
    var isExpanded: Bool
    var goalEvent: OverlayManager.GoalEvent?
    var varEvent: OverlayManager.VAREvent?
    var isMatchFinished: Bool = false
    var homeTeamColor: Color = .blue
    var awayTeamColor: Color = .red
    /// Timestamp of next scheduled live poll — drives the "xx:xx to update" countdown.
    var nextUpdateAt: Date?
    var onClose: () -> Void
    var onToggleExpand: () -> Void

    static let collapsedWidth: CGFloat = 360
    static let collapsedBaseHeight: CGFloat = 140

    /// Collapsed height — fixed base plus optional countdown row when live
    var collapsedHeight: CGFloat {
        Self.collapsedHeightForEvents(0, includeCountdown: match.status.isLive && nextUpdateAt != nil)
    }

    static func collapsedHeightForEvents(_ count: Int, includeCountdown: Bool = false) -> CGFloat {
        let countdownHeight: CGFloat = includeCountdown ? 18 : 0
        return collapsedBaseHeight + countdownHeight
    }
    static let expandedWidth: CGFloat = 460
    static let expandedHeight: CGFloat = 680

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            // Countdown to next update — only when match is live and we have a target
            if match.status.isLive, let target = nextUpdateAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    countdownLabel(target: target, now: context.date)
                }
                .padding(.top, 6)
            }

            // League header
            HStack {
                HStack(spacing: 5) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(match.leagueName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let venue = match.venueName {
                            Text(venue)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                // Expand/collapse button
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // Main score area
            HStack(spacing: 14) {
                // Home team
                VStack(spacing: 4) {
                    TeamBadge(size: 36)

                    Text(match.homeTeam.name)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 85)
                }

                // Score + Clock
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Text("\(match.homeScore)")
                            .font(.title.bold().monospacedDigit())
                        Text("-")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("\(match.awayScore)")
                            .font(.title.bold().monospacedDigit())
                    }

                    statusBadge
                }

                // Away team
                VStack(spacing: 4) {
                    TeamBadge(size: 36)

                    Text(match.awayTeam.name)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 85)
                }
            }
            .padding(.horizontal, 14)

            // Possession bar + SOG (always visible if data available)
            if let possession = match.possession {
                PossessionBarView(
                    homePercent: possession.home,
                    awayPercent: possession.away,
                    homePossessing: match.teamInPossession,
                    homeColor: homeTeamColor,
                    awayColor: awayTeamColor
                )
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }

            // SOG in collapsed view
            if let shots = match.shotsOnTarget {
                HStack {
                    Text("\(shots.home)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                    Spacer()
                    Text("SOG")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(shots.away)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
            }



            // MARK: - Expanded Stats + Lineups
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        // Stats section
                        if let possession = match.possession {
                            statRow(title: "Possession", home: "\(possession.home)%", away: "\(possession.away)%")
                        }
                        if let shots = match.shotsOnTarget {
                            statRow(title: "Shots on Target", home: "\(shots.home)", away: "\(shots.away)")
                        }
                        if let total = match.totalShots {
                            statRow(title: "Total Shots", home: "\(total.home)", away: "\(total.away)")
                        }
                        if let corners = match.corners {
                            statRow(title: "Corners", home: "\(corners.home)", away: "\(corners.away)")
                        }
                        if let fouls = match.fouls {
                            statRow(title: "Fouls", home: "\(fouls.home)", away: "\(fouls.away)")
                        }
                        if let saves = match.saves {
                            statRow(title: "GK Saves", home: "\(saves.home)", away: "\(saves.away)")
                        }
                        if let offsides = match.offsides {
                            statRow(title: "Offsides", home: "\(offsides.home)", away: "\(offsides.away)")
                        }
                        if let xg = match.xG {
                            statRow(title: "xG", home: xg.home, away: xg.away)
                        }

                        // Derive yellow/red counts from events when available —
                        // more accurate than the stats endpoint for late-match cards
                        if !match.events.isEmpty {
                            let homeYellows = match.events.filter { $0.teamID == match.homeTeam.id && $0.type == .yellowCard }.count
                            let awayYellows = match.events.filter { $0.teamID == match.awayTeam.id && $0.type == .yellowCard }.count
                            let homeReds = match.events.filter { $0.teamID == match.homeTeam.id && $0.type == .redCard }.count
                            let awayReds = match.events.filter { $0.teamID == match.awayTeam.id && $0.type == .redCard }.count

                            if homeYellows > 0 || awayYellows > 0 {
                                statRow(title: "Yellow Cards", home: "\(homeYellows)", away: "\(awayYellows)")
                            }
                            if homeReds > 0 || awayReds > 0 {
                                statRow(title: "Red Cards", home: "\(homeReds)", away: "\(awayReds)")
                            }
                        } else {
                            // Fall back to stats API values before events are loaded
                            if let yellows = match.yellowCards {
                                statRow(title: "Yellow Cards", home: "\(yellows.home)", away: "\(yellows.away)")
                            }
                            if let reds = match.redCards {
                                statRow(title: "Red Cards", home: "\(reds.home)", away: "\(reds.away)")
                            }
                        }

                        // No stats message
                        if match.possession == nil && match.shotsOnTarget == nil {
                            Text("Stats not available yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }

                        // Referee
                        if let referee = match.referee {
                            HStack {
                                Spacer()
                                Text("⚑ \(referee)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }

                        // MARK: - Full Timeline Section (goals, cards, VAR, subs)
                        let timelineEvents = (match.events + match.rescindedEvents + match.substitutions)
                            .sorted { eventSortKey($0.minute) < eventSortKey($1.minute) }

                        if !timelineEvents.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            Text("TIMELINE")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.bottom, 2)

                            ForEach(timelineEvents) { event in
                                timelineRow(event: event)
                            }
                        }

                        // MARK: - Penalty Shootout Section
                        if !match.shootoutEvents.isEmpty || match.penaltyScore != nil {
                            Divider()
                                .padding(.vertical, 4)

                            // Header with aggregate score
                            HStack {
                                Spacer()
                                Text("PENALTIES")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                if let ps = match.penaltyScore {
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text("\(ps.home) – \(ps.away)")
                                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                                }
                                Spacer()
                            }
                            .padding(.bottom, 2)

                            // Two columns: home kicks on left, away kicks on right
                            let homePSO = match.shootoutEvents
                                .filter { $0.teamID == match.homeTeam.id }
                                .sorted { eventSortKey($0.minute) < eventSortKey($1.minute) }
                            let awayPSO = match.shootoutEvents
                                .filter { $0.teamID == match.awayTeam.id }
                                .sorted { eventSortKey($0.minute) < eventSortKey($1.minute) }
                            let psoCount = max(homePSO.count, awayPSO.count)

                            ForEach(0..<psoCount, id: \.self) { i in
                                HStack(spacing: 4) {
                                    // Home kick
                                    if i < homePSO.count {
                                        let kick = homePSO[i]
                                        HStack(spacing: 3) {
                                            Text(abbreviateName(kick.playerName))
                                                .font(.system(size: 9))
                                                .lineLimit(1)
                                            eventIcon(for: kick.type)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    } else {
                                        Spacer().frame(maxWidth: .infinity)
                                    }

                                    Divider().frame(height: 12)

                                    // Away kick
                                    if i < awayPSO.count {
                                        let kick = awayPSO[i]
                                        HStack(spacing: 3) {
                                            eventIcon(for: kick.type)
                                            Text(abbreviateName(kick.playerName))
                                                .font(.system(size: 9))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Spacer().frame(maxWidth: .infinity)
                                    }
                                }
                                .frame(minHeight: 14)
                            }
                        }

                        // MARK: - Lineups Section
                        if let lineups = match.lineups {
                            Divider()
                                .padding(.vertical, 4)

                            // Formation labels + coach names
                            HStack {
                                Text(lineups.home.formation)
                                    .font(.system(size: 10, weight: .bold))
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text("LINEUPS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(lineups.away.formation)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            // Coach names
                            if lineups.home.coachName != nil || lineups.away.coachName != nil {
                                HStack {
                                    Text(lineups.home.coachName.map { "👨‍💼 \($0)" } ?? "")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(lineups.away.coachName.map { "👨‍💼 \($0)" } ?? "")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }

                            // Football pitch with formations
                            FootballPitchView(
                                homeXI: lineups.home.startingXI,
                                awayXI: lineups.away.startingXI,
                                events: match.events,
                                playerRatings: match.playerRatings,
                                substitutedOffIDs: Set(match.substitutions.compactMap(\.playerID)),
                                captainIDs: match.captainIDs
                            )
                            .frame(height: 380)
                            .padding(.top, 4)

                            // Bench
                            Text("BENCH")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 6)

                            benchList(
                                home: lineups.home.substitutes,
                                away: lineups.away.substitutes
                            )

                        } else if match.status.isLive || match.status.isFinished {
                            Divider()
                                .padding(.vertical, 4)

                            Text("Lineups not available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }

            // Attribution
            Text("Data from API-Football · Powered by [Your Server]")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            Spacer().frame(height: isExpanded ? 0 : 4)
        }
        .frame(
            width: isExpanded ? Self.expandedWidth : Self.collapsedWidth,
            height: isExpanded ? Self.expandedHeight : collapsedHeight
        )

            // Goal animation overlay
            if let goal = goalEvent {
                GoalAnimationView(
                    teamColor: goal.teamColor,
                    teamName: goal.teamName,
                    score: goal.score
                )
            }

            // VAR / No Goal animation overlay
            if let var_ = varEvent {
                VARAnimationView(
                    teamName: var_.teamName,
                    teamColor: var_.teamColor,
                    scorerName: var_.scorerName,
                    score: var_.score
                )
            }
        } // ZStack
        .frame(
            width: isExpanded ? Self.expandedWidth : Self.collapsedWidth,
            height: isExpanded ? Self.expandedHeight : collapsedHeight
        )
        .glassEffect(.regular, in: Rectangle())
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .opacity(isMatchFinished ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .animation(.easeInOut(duration: 0.5), value: isMatchFinished)
    }

    // MARK: - Bench List

    private func benchList(home: [LineupPlayer], away: [LineupPlayer]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Home bench
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(home) { player in
                    benchPlayerRow(player, isHome: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Away bench
            VStack(alignment: .leading, spacing: 2) {
                ForEach(away) { player in
                    benchPlayerRow(player, isHome: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func benchPlayerRow(_ player: LineupPlayer, isHome: Bool) -> some View {
        let pid = player.id
        let isSubbedOn  = pid.map { id in match.substitutions.contains { $0.assistID == id } } ?? false
        let rating      = pid.flatMap { match.playerRatings[$0] }
        let hasGoal     = pid.map { id in match.events.contains { ($0.type == .goal || $0.type == .penalty) && $0.playerID == id } } ?? false
        let hasOwnGoal  = pid.map { id in match.events.contains { $0.type == .ownGoal && $0.playerID == id } } ?? false
        let hasAssist   = pid.map { id in match.events.contains { ($0.type == .goal || $0.type == .penalty) && $0.assistID == id } } ?? false
        let hasYellow   = pid.map { id in match.events.contains { $0.type == .yellowCard && $0.playerID == id } } ?? false
        let hasRed      = pid.map { id in match.events.contains { $0.type == .redCard && $0.playerID == id } } ?? false

        let ratingColor: Color = {
            guard let r = rating else { return .secondary }
            if r >= 8.5 { return .yellow }
            if r >= 7.0 { return .green }
            if r < 6.0  { return .orange }
            return .secondary
        }()

        // Icons that appear between the name and the number
        @ViewBuilder
        func icons() -> some View {
            if hasGoal {
                Image(systemName: "soccerball").font(.system(size: 7))
            }
            if hasOwnGoal {
                Image(systemName: "soccerball").font(.system(size: 7)).foregroundStyle(.red)
            }
            if hasAssist {
                Text("A")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 0.5)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.secondary.opacity(0.5), lineWidth: 0.5))
            }
            if hasRed {
                RoundedRectangle(cornerRadius: 1).fill(.red).frame(width: 5, height: 7)
            } else if hasYellow {
                RoundedRectangle(cornerRadius: 1).fill(.yellow).frame(width: 5, height: 7)
            }
        }

        return HStack(spacing: 3) {
            if isHome {
                // Home: [↑67'] [rating] [icons] Name  #
                if isSubbedOn {
                    let mins = pid.flatMap { match.playerMinutes[$0] }
                    if let mins = mins {
                        Text("↑\(mins)'")
                            .font(.system(size: 7, weight: .bold).monospacedDigit())
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
                if let r = rating {
                    Text(String(format: "%.1f", r))
                        .font(.system(size: 7, weight: .semibold).monospacedDigit())
                        .foregroundStyle(ratingColor)
                }
                icons()
                Text(abbreviateName(player.name))
                    .font(.system(size: 9))
                    .foregroundStyle(isSubbedOn ? .primary : .secondary)
                    .lineLimit(1)
                if let number = player.number {
                    Text("\(number)")
                        .font(.system(size: 8, weight: .bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .trailing)
                }
            } else {
                // Away: #  Name [icons] [rating] [↑67']
                if let number = player.number {
                    Text("\(number)")
                        .font(.system(size: 8, weight: .bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .leading)
                }
                Text(abbreviateName(player.name))
                    .font(.system(size: 9))
                    .foregroundStyle(isSubbedOn ? .primary : .secondary)
                    .lineLimit(1)
                icons()
                if let r = rating {
                    Text(String(format: "%.1f", r))
                        .font(.system(size: 7, weight: .semibold).monospacedDigit())
                        .foregroundStyle(ratingColor)
                }
                if isSubbedOn {
                    let mins = pid.flatMap { match.playerMinutes[$0] }
                    if let mins = mins {
                        Text("↑\(mins)'")
                            .font(.system(size: 7, weight: .bold).monospacedDigit())
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    /// Abbreviates a player name: "Bukayo Saka" -> "B. Saka"
    private func abbreviateName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard parts.count > 1 else { return name }
        let firstName = parts.first!
        let rest = parts.dropFirst().joined(separator: " ")
        return "\(firstName.prefix(1)). \(rest)"
    }

    // MARK: - Event Icon

    @ViewBuilder
    private func eventIcon(for type: MatchEventType) -> some View {
        switch type {
        case .goal:
            Image(systemName: "soccerball")
                .font(.system(size: 8))
        case .penalty:
            HStack(spacing: 1) {
                Image(systemName: "soccerball")
                    .font(.system(size: 8))
                Text("P")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        case .ownGoal:
            Image(systemName: "soccerball")
                .font(.system(size: 8))
                .foregroundStyle(.red)
        case .redCard:
            Text("\u{1F7E5}")
                .font(.system(size: 8))
        case .yellowCard:
            Text("\u{1F7E8}")
                .font(.system(size: 8))
        case .substitution:
            Text("🔄")
                .font(.system(size: 8))
        case .penaltyShootoutScored:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.green)
        case .penaltyShootoutMissed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
        case .penaltyShootoutSaved:
            Text("🧤")
                .font(.system(size: 8))
        }
    }

    // MARK: - Event Row

    private func eventRow(event: MatchEvent) -> some View {
        let isHome = event.teamID == match.homeTeam.id

        return HStack(spacing: 4) {
            if isHome {
                HStack(spacing: 3) {
                    if let assist = event.assistName, event.type == .goal || event.type == .penalty {
                        Text("(\(abbreviateName(assist)))")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(abbreviateName(event.playerName))
                        .font(.system(size: 9))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                eventIcon(for: event.type)
                Text(event.minute)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .center)
                Spacer()
                    .frame(maxWidth: .infinity)
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
                Text(event.minute)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .center)
                eventIcon(for: event.type)
                HStack(spacing: 3) {
                    Text(abbreviateName(event.playerName))
                        .font(.system(size: 9))
                        .lineLimit(1)
                    if let assist = event.assistName, event.type == .goal || event.type == .penalty {
                        Text("(\(abbreviateName(assist)))")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 14)
    }

    // MARK: - Timeline Row (goals, cards, VAR rescissions, substitutions)

    private func timelineRow(event: MatchEvent) -> some View {
        let isHome = event.teamID == match.homeTeam.id
        let rescinded = event.isRescinded
        let isSub = event.type == .substitution

        return HStack(spacing: 4) {
            if isHome {
                // ── Name column (trailing) with icon tucked inside ──────────
                HStack(spacing: 3) {
                    if rescinded {
                        Text("VAR")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                    if isSub {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("↑ \(abbreviateName(event.assistName ?? "?"))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                            Text("↓ \(abbreviateName(event.playerName))")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        if let assist = event.assistName, event.type == .goal || event.type == .penalty {
                            Text("(\(abbreviateName(assist)))")
                                .font(.system(size: 8))
                                .foregroundStyle(rescinded ? AnyShapeStyle(.secondary.opacity(0.5)) : AnyShapeStyle(.secondary))
                                .strikethrough(rescinded, color: .red.opacity(0.7))
                                .lineLimit(1)
                        }
                        Text(abbreviateName(event.playerName))
                            .font(.system(size: 9))
                            .foregroundStyle(rescinded ? .secondary : .primary)
                            .strikethrough(rescinded, color: .red.opacity(0.7))
                            .lineLimit(1)
                    }
                    // Icon lives inside the name column → minute stays centered
                    eventIcon(for: event.type)
                        .opacity(rescinded ? 0.35 : 1.0)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                // ── Minute (always at the same x position) ──────────────────
                Text(event.minute)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .center)

                Spacer().frame(maxWidth: .infinity)

            } else {
                Spacer().frame(maxWidth: .infinity)

                // ── Minute (always at the same x position) ──────────────────
                Text(event.minute)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .center)

                // ── Icon + name column (leading) ─────────────────────────────
                HStack(spacing: 3) {
                    // Icon lives inside the name column → minute stays centered
                    eventIcon(for: event.type)
                        .opacity(rescinded ? 0.35 : 1.0)
                    if isSub {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("↑ \(abbreviateName(event.assistName ?? "?"))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                            Text("↓ \(abbreviateName(event.playerName))")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text(abbreviateName(event.playerName))
                            .font(.system(size: 9))
                            .foregroundStyle(rescinded ? .secondary : .primary)
                            .strikethrough(rescinded, color: .red.opacity(0.7))
                            .lineLimit(1)
                        if let assist = event.assistName, event.type == .goal || event.type == .penalty {
                            Text("(\(abbreviateName(assist)))")
                                .font(.system(size: 8))
                                .foregroundStyle(rescinded ? AnyShapeStyle(.secondary.opacity(0.5)) : AnyShapeStyle(.secondary))
                                .strikethrough(rescinded, color: .red.opacity(0.7))
                                .lineLimit(1)
                        }
                        if rescinded {
                            Text("VAR")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: isSub ? 24 : 14)
    }

    // MARK: - Stat Row

    private func statRow(title: String, home: String, away: String) -> some View {
        HStack {
            Text(home)
                .font(.caption.monospacedDigit())
                .frame(width: 45, alignment: .trailing)
            Spacer()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(away)
                .font(.caption.monospacedDigit())
                .frame(width: 45, alignment: .leading)
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        if match.status.isLive {
            Text(match.clock)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red, in: Capsule())
        } else if match.status.isFinished {
            Text("FT")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        } else {
            Text(formatKickoff(match.kickoffDate))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Parse a minute string like "45'" or "45+3'" into a sortable integer.
    /// "45'" → 4500, "45+3'" → 4503 — keeps stoppage-time events ordered correctly
    /// between the regular minute and the next minute.
    private func eventSortKey(_ minute: String) -> Int {
        let cleaned = minute.replacingOccurrences(of: "'", with: "")
        let parts = cleaned.split(separator: "+")
        let elapsed = Int(parts.first ?? "0") ?? 0
        let extra = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return elapsed * 100 + extra
    }

    private func formatKickoff(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func countdownLabel(target: Date, now: Date) -> some View {
        let remaining = max(0, Int(target.timeIntervalSince(now).rounded()))
        let mins = remaining / 60
        let secs = remaining % 60
        let timeText = String(format: "%02d:%02d", mins, secs)

        if match.status.isHalftime {
            Text("HALFTIME — updates paused")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            Text("\(timeText) to update")
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Possession Bar

struct PossessionBarView: View {
    let homePercent: Int
    let awayPercent: Int
    var homePossessing: Bool? = nil  // nil = unknown, true = home has ball, false = away
    var homeColor: Color = .blue
    var awayColor: Color = .red

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(homeColor)
                        .frame(width: geo.size.width * CGFloat(homePercent) / 100)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(awayColor)
                }
            }
            .frame(height: 3)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.6), value: homePercent)

            HStack {
                HStack(spacing: 3) {
                    if homePossessing == true {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                    }
                    Text("\(homePercent)%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Possession")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                HStack(spacing: 3) {
                    Text("\(awayPercent)%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    if homePossessing == false {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
    }
}

// MARK: - Football Pitch Formation View

struct FootballPitchView: View {
    let homeXI: [LineupPlayer]
    let awayXI: [LineupPlayer]
    var events: [MatchEvent] = []
    var playerRatings: [Int: Double] = [:]
    var substitutedOffIDs: Set<Int> = []
    var captainIDs: Set<Int> = []

    /// Card type for a given player — red (including second yellow) takes priority over yellow.
    private func cardType(for player: LineupPlayer) -> MatchEventType? {
        guard let pid = player.id else { return nil }
        let cardEvents = events.filter {
            ($0.type == .yellowCard || $0.type == .redCard) && $0.playerID == pid
        }
        if cardEvents.contains(where: { $0.type == .redCard }) { return .redCard }
        if cardEvents.contains(where: { $0.type == .yellowCard }) { return .yellowCard }
        return nil
    }

    /// Goal badge for a player dot — SF Symbol soccerball, red tint for own goals.
    /// Regular goal takes priority if they somehow have both.
    @ViewBuilder
    private func goalBadgeView(for player: LineupPlayer) -> some View {
        if let pid = player.id {
            let scored = events.contains { ($0.type == .goal || $0.type == .penalty) && $0.playerID == pid }
            let ownGoal = !scored && events.contains { $0.type == .ownGoal && $0.playerID == pid }
            if scored {
                Image(systemName: "soccerball")
                    .font(.system(size: 8))
            } else if ownGoal {
                Image(systemName: "soccerball")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
            }
        }
    }

    /// Rating colour: gold ≥ 8.5, green ≥ 7.0, orange < 6.0, default otherwise.
    private func ratingColor(_ rating: Double) -> Color {
        if rating >= 8.5 { return .yellow }
        if rating >= 7.0 { return .green }
        if rating < 6.0  { return .orange }
        return .white.opacity(0.75)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Pitch background
                Rectangle()
                    .fill(Color(red: 0.18, green: 0.55, blue: 0.24))

                // Field markings
                pitchMarkings(width: w, height: h)

                // Home team (top half) — row 1 = GK at top
                ForEach(positionedPlayers(homeXI, inRect: CGRect(x: 0, y: 0, width: w, height: h / 2), flipped: false)) { pp in
                    playerDot(pp, isHome: true)
                }

                // Away team (bottom half) — row 1 = GK at bottom
                ForEach(positionedPlayers(awayXI, inRect: CGRect(x: 0, y: h / 2, width: w, height: h / 2), flipped: true)) { pp in
                    playerDot(pp, isHome: false)
                }
            }
        }
        .clipShape(Rectangle())
    }

    // MARK: - Pitch Markings

    private func pitchMarkings(width w: CGFloat, height h: CGFloat) -> some View {
        Canvas { context, _ in
            let lineColor = Color.white.opacity(0.3)

            // Outer border
            let border = Path(CGRect(x: 2, y: 2, width: w - 4, height: h - 4))
            context.stroke(border, with: .color(lineColor), lineWidth: 1)

            // Halfway line
            var halfway = Path()
            halfway.move(to: CGPoint(x: 2, y: h / 2))
            halfway.addLine(to: CGPoint(x: w - 2, y: h / 2))
            context.stroke(halfway, with: .color(lineColor), lineWidth: 1)

            // Center circle
            let circleR: CGFloat = min(w, h) * 0.12
            let center = CGPoint(x: w / 2, y: h / 2)
            let circle = Path(ellipseIn: CGRect(x: center.x - circleR, y: center.y - circleR, width: circleR * 2, height: circleR * 2))
            context.stroke(circle, with: .color(lineColor), lineWidth: 1)

            // Center dot
            let dotR: CGFloat = 2
            let dot = Path(ellipseIn: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2))
            context.fill(dot, with: .color(lineColor))

            // Penalty boxes
            let boxW: CGFloat = w * 0.44
            let boxH: CGFloat = h * 0.12
            // Top
            let topBox = Path(CGRect(x: (w - boxW) / 2, y: 2, width: boxW, height: boxH))
            context.stroke(topBox, with: .color(lineColor), lineWidth: 1)
            // Bottom
            let botBox = Path(CGRect(x: (w - boxW) / 2, y: h - boxH - 2, width: boxW, height: boxH))
            context.stroke(botBox, with: .color(lineColor), lineWidth: 1)

            // Goal areas (smaller boxes)
            let goalW: CGFloat = w * 0.22
            let goalH: CGFloat = h * 0.05
            let topGoal = Path(CGRect(x: (w - goalW) / 2, y: 2, width: goalW, height: goalH))
            context.stroke(topGoal, with: .color(lineColor), lineWidth: 1)
            let botGoal = Path(CGRect(x: (w - goalW) / 2, y: h - goalH - 2, width: goalW, height: goalH))
            context.stroke(botGoal, with: .color(lineColor), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Position Players

    private struct PositionedPlayer: Identifiable {
        let id: String
        let player: LineupPlayer
        let x: CGFloat
        let y: CGFloat
    }

    /// Parse grid positions and map to coordinates within the given rect.
    /// Grid format from API: "row:col" — row 1 = GK, higher rows = further up pitch.
    /// flipped = true means row 1 is at the bottom (away team).
    private func positionedPlayers(_ players: [LineupPlayer], inRect rect: CGRect, flipped: Bool) -> [PositionedPlayer] {
        // Group players by row
        var rows: [Int: [(col: Int, player: LineupPlayer)]] = [:]
        var maxRow = 1

        for player in players {
            guard let grid = player.grid,
                  let sepIdx = grid.firstIndex(of: ":") else { continue }
            let row = Int(grid[grid.startIndex..<sepIdx]) ?? 1
            let col = Int(grid[grid.index(after: sepIdx)...]) ?? 1
            rows[row, default: []].append((col: col, player: player))
            maxRow = max(maxRow, row)
        }

        var result: [PositionedPlayer] = []

        // Generous padding so dots don't hug edges — more horizontal room for wide rows
        let padX: CGFloat = 32
        let padY: CGFloat = 22

        let usableW = rect.width - padX * 2
        let usableH = rect.height - padY * 2

        // Sort row keys so spacing is deterministic
        let sortedRowKeys = rows.keys.sorted()
        let rowCount = sortedRowKeys.count

        // Largest row in this team's half determines full-width reference
        let maxPlayersInRow = rows.values.map(\.count).max() ?? 1

        for (rowIndex, rowKey) in sortedRowKeys.enumerated() {
            guard let cols = rows[rowKey] else { continue }
            let sorted = cols.sorted { $0.col < $1.col }
            let totalInRow = sorted.count

            // Y: evenly space rows with equal gutters between them
            let rowFraction: CGFloat
            if rowCount == 1 {
                rowFraction = 0.5
            } else {
                rowFraction = CGFloat(rowIndex) / CGFloat(rowCount - 1)
            }

            let yNorm = flipped ? (1.0 - rowFraction) : rowFraction
            let y = rect.minY + padY + usableH * yNorm

            for (i, entry) in sorted.enumerated() {
                // X: scale spread proportionally to the widest row.
                // Back 4 in a 4-x-x = full width; row of 2 = ~33%; row of 3 = ~67%.
                // This naturally shapes the formation on the pitch.
                let x: CGFloat
                if totalInRow == 1 {
                    x = rect.midX
                } else {
                    let rawFraction = CGFloat(totalInRow - 1) / CGFloat(max(maxPlayersInRow - 1, 1))
                    let spreadFraction = max(0.30, rawFraction) // minimum 30% so pairs aren't stacked
                    let rowWidth = usableW * spreadFraction
                    let rowStartX = rect.midX - rowWidth / 2
                    x = rowStartX + rowWidth * CGFloat(i) / CGFloat(totalInRow - 1)
                }

                result.append(PositionedPlayer(
                    id: "\(entry.player.id ?? 0)_\(rowKey)_\(entry.col)",
                    player: entry.player,
                    x: x,
                    y: y
                ))
            }
        }

        return result
    }

    // MARK: - Player Dot

    private func playerDot(_ pp: PositionedPlayer, isHome: Bool) -> some View {
        let card = cardType(for: pp.player)
        let pid = pp.player.id
        let isSubbedOff = pid.map { substitutedOffIDs.contains($0) } ?? false
        let rating = pid.flatMap { playerRatings[$0] }
        let isCaptain = pid.map { captainIDs.contains($0) } ?? false

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isHome ? Color.white : Color(red: 0.95, green: 0.85, blue: 0.3))
                    .frame(width: 20, height: 20)
                    .opacity(isSubbedOff ? 0.35 : 1.0)
                if let number = pp.player.number {
                    Text("\(number)")
                        .font(.system(size: 8, weight: .bold).monospacedDigit())
                        .foregroundStyle(.black)
                        .opacity(isSubbedOff ? 0.4 : 1.0)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Card badge — top-right. Red overrides yellow (second yellow → red only).
                if let card = card {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(card == .redCard ? Color.red : Color.yellow)
                        .frame(width: 7, height: 9)
                        .offset(x: 3, y: -3)
                }
            }
            .overlay(alignment: .topLeading) {
                // Goal badge — top-left. SF Symbol soccerball, red for own goals.
                goalBadgeView(for: pp.player)
                    .offset(x: -3, y: -3)
            }
            .overlay(alignment: .bottomLeading) {
                // Captain armband badge — bottom-left of circle
                if isCaptain {
                    Text("C")
                        .font(.system(size: 5, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 9, height: 9)
                        .background(.yellow, in: Circle())
                        .offset(x: -3, y: 5)
                }
            }
            .overlay(alignment: .bottom) {
                // Rating pill — anchored to bottom edge of the circle so it never
                // adds vertical height to the VStack and can't cover neighbouring rows.
                if let rating = rating {
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 6, weight: .bold).monospacedDigit())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 2.5)
                        .padding(.vertical, 1)
                        .background(ratingColor(rating), in: Capsule())
                        .offset(y: 7)   // half in, half out of the circle
                }
            }

            Text(lastName(pp.player.name))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(isSubbedOff ? .white.opacity(0.4) : .white)
                .lineLimit(1)
                .frame(width: 60)
                .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
        }
        .position(x: pp.x, y: pp.y)
    }

    private func lastName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard parts.count > 1 else { return name }
        return String(parts.last!)
    }
}
