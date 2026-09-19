//
//  MenuBarView.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Query(sort: \FavoriteTeam.name) private var favoriteTeams: [FavoriteTeam]
    @Query(sort: \FavoriteLeague.name) private var favoriteLeagues: [FavoriteLeague]

    var matchMonitor: MatchMonitor
    var overlayManager: OverlayManager
    var onOpenSettings: () -> Void
    var onOpenFullApp: () -> Void
    var onQuit: () -> Void

    // Priority leagues show at the top
    private var sortedLeagueGroups: [LeagueGroup] {
        matchMonitor.leagueGroups.sorted { a, b in
            let aPriority = MatchMonitor.priorityLeagueIDs.contains(a.id)
            let bPriority = MatchMonitor.priorityLeagueIDs.contains(b.id)
            if aPriority != bPriority { return aPriority }
            return a.name < b.name
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Label("Football Overlay", systemImage: "sportscourt.fill")
                        .font(.headline)
                    Spacer()
                }

                // Active overlays indicator
                if !overlayManager.activeMatches.isEmpty {
                    Divider()
                    Section {
                        ForEach(overlayManager.activeMatches) { match in
                            HStack {
                                Image(systemName: "pip.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text("\(match.homeTeam.name) vs \(match.awayTeam.name)")
                                    .font(.callout)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    overlayManager.closeOverlay(fixtureID: match.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Label("Active Overlays", systemImage: "pip.fill")
                            .font(.subheadline.bold())
                    }
                }

                Divider()

                // MARK: - Live Matches
                if !matchMonitor.liveMatches.isEmpty {
                    Section {
                        ForEach(matchMonitor.liveMatches) { match in
                            liveMatchRow(match)
                        }
                    } header: {
                        HStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                    Divider()
                }

                // MARK: - Today's Matches by League
                if matchMonitor.leagueGroups.isEmpty {
                    if favoriteLeagues.isEmpty {
                        Text("Add favorite leagues to see today's matches")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        Text("No matches today for your leagues")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    ForEach(sortedLeagueGroups) { group in
                        LeagueSection(group: group, overlayManager: overlayManager)
                    }
                }

                // Error display
                if let error = matchMonitor.lastError {
                    Divider()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Divider()

                Button {
                    onOpenFullApp()
                } label: {
                    Label("Open Full App", systemImage: "macwindow")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut("o")

                Button("Settings...") {
                    onOpenSettings()
                }

                Button("Quit Football Overlay") {
                    onQuit()
                }
                .keyboardShortcut("q")
            }
            .padding()
        }
        .frame(width: 320, height: 480)
    }

    // MARK: - Live Match Row

    private func liveMatchRow(_ match: LiveMatch) -> some View {
        Button {
            overlayManager.openOverlay(for: match)
        } label: {
            VStack(spacing: 4) {
                HStack {
                    TeamBadge(size: 18, teamName: match.homeTeam.name)

                    Text(match.homeTeam.name)
                        .font(.callout)
                        .lineLimit(1)

                    Spacer()

                    Text("\(match.homeScore)")
                        .font(.callout.bold().monospacedDigit())
                }

                HStack {
                    TeamBadge(size: 18, teamName: match.awayTeam.name)

                    Text(match.awayTeam.name)
                        .font(.callout)
                        .lineLimit(1)

                    Spacer()

                    Text("\(match.awayScore)")
                        .font(.callout.bold().monospacedDigit())
                }

                HStack {
                    Text(match.clock)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - League Section (Collapsible)

struct LeagueSection: View {
    let group: LeagueGroup
    var overlayManager: OverlayManager
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // League header — tap to collapse/expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    LeagueBadge(size: 20)

                    Text(group.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text("\(group.matches.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Match rows — exclude live games (they already appear in the LIVE section above)
            if isExpanded {
                ForEach(group.matches.filter { !$0.status.isLive }) { match in
                    fixtureRow(match)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func fixtureRow(_ match: LiveMatch) -> some View {
        Button {
            overlayManager.openOverlay(for: match)
        } label: {
            HStack(spacing: 0) {
                // Home team
                HStack(spacing: 4) {
                    Text(match.homeTeam.name)
                        .font(.callout)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    TeamBadge(size: 16, teamName: match.homeTeam.name)
                }
                .frame(maxWidth: .infinity)

                // Score or time
                Group {
                    if match.status.isLive {
                        Text("\(match.homeScore) - \(match.awayScore)")
                            .foregroundStyle(.red)
                    } else if match.status.isFinished {
                        Text("\(match.homeScore) - \(match.awayScore)")
                            .foregroundStyle(.primary)
                    } else {
                        Text(formatKickoff(match.kickoffDate))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout.bold().monospacedDigit())
                .frame(width: 56, alignment: .center)

                // Away team
                HStack(spacing: 4) {
                    TeamBadge(size: 16, teamName: match.awayTeam.name)

                    Text(match.awayTeam.name)
                        .font(.callout)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 2)
            .padding(.leading, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatKickoff(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
