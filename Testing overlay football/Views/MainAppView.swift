//
//  MainAppView.swift
//  Testing overlay football
//

import SwiftUI
import SwiftData

// MARK: - Navigation Section

enum AppSection: Hashable {
    case liveNow
    case today
    case standings
    case seasonStats
    case settings
}

enum SeasonStatType: String, CaseIterable {
    case topScorers  = "Top Scorers"
    case topAssists  = "Top Assists"
    case topRatings  = "Top Ratings"

    var icon: String {
        switch self {
        case .topScorers: return "⚽"
        case .topAssists: return "🪄"
        case .topRatings: return "⭐"
        }
    }

    var primaryColumn: String {
        switch self {
        case .topScorers: return "Goals"
        case .topAssists: return "Assists"
        case .topRatings: return "Rating"
        }
    }
}

// Leagues that have both a group stage and a knockout bracket.
// For these the Standings view shows a "Knockout" tab alongside "Table".
private let knockoutLeagueIDs: Set<Int> = [
    1,   // FIFA World Cup
    2,   // UEFA Champions League
    3,   // UEFA Europa League
    6,   // FIFA Women's World Cup
    848, // UEFA Conference League
]

private enum StandingsTab: String, CaseIterable {
    case table    = "Table"
    case knockout = "Knockout"
}

// MARK: - Root Container

@MainActor
struct MainAppView: View {
    var matchMonitor: MatchMonitor
    var overlayManager: OverlayManager

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: AppSection = .today

    private var backgroundGradient: LinearGradient {
        colorScheme == .dark
            ? LinearGradient(colors: [Color(white: 0.07), Color(white: 0.11)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(white: 0.94), Color(white: 0.90)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                selected: $selectedSection,
                liveCount: matchMonitor.liveMatches.count
            )
            .frame(width: 210)

            // Hairline divider
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)

            // Content
            Group {
                switch selectedSection {
                case .liveNow:
                    AppLiveNowView(matchMonitor: matchMonitor, overlayManager: overlayManager)
                case .today:
                    AppTodayView(matchMonitor: matchMonitor, overlayManager: overlayManager)
                case .standings:
                    AppStandingsView()
                case .seasonStats:
                    AppSeasonStatsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                Text("Data from API-Football · Powered by [Your Server]")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .background(backgroundGradient)
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSettings)) { _ in
            selectedSection = .settings
        }
    }
}

// MARK: - Sidebar

private struct AppSidebar: View {
    @Binding var selected: AppSection
    let liveCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App header
            HStack(spacing: 10) {
                Text("⚽")
                    .font(.title2)
                Text("Football")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 24)

            // Nav items
            VStack(alignment: .leading, spacing: 4) {
                if liveCount > 0 {
                    SidebarItem(
                        label: "Live Now",
                        icon: "dot.radiowaves.left.and.right",
                        iconColor: .red,
                        badge: "\(liveCount)",
                        isSelected: selected == .liveNow
                    ) { selected = .liveNow }
                }

                SidebarItem(
                    label: "Today",
                    icon: "calendar",
                    iconColor: .blue,
                    isSelected: selected == .today
                ) { selected = .today }

                SidebarItem(
                    label: "Standings",
                    icon: "list.number",
                    iconColor: .orange,
                    isSelected: selected == .standings
                ) { selected = .standings }

                SidebarItem(
                    label: "Season Stats",
                    icon: "chart.bar.fill",
                    iconColor: .yellow,
                    isSelected: selected == .seasonStats
                ) { selected = .seasonStats }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Footer — Settings pinned to bottom
            VStack(alignment: .leading, spacing: 4) {
                Divider().opacity(0.3)
                    .padding(.bottom, 4)

                SidebarItem(
                    label: "Settings",
                    icon: "gearshape.fill",
                    iconColor: .secondary,
                    isSelected: selected == .settings
                ) { selected = .settings }

                Spacer().frame(height: 12)
            }
        }
        .background(Color.primary.opacity(0.05))
    }
}

private struct SidebarItem: View {
    let label: String
    let icon: String
    let iconColor: Color
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? iconColor : .secondary)
                    .frame(width: 18)

                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable error + retry view

private struct RetryableErrorView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Try Again", action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Live Now

struct AppLiveNowView: View {
    var matchMonitor: MatchMonitor
    var overlayManager: OverlayManager

    let columns = [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 14)]

    var body: some View {
        if matchMonitor.liveMatches.isEmpty {
            ContentUnavailableView("No Live Matches", systemImage: "dot.radiowaves.left.and.right",
                                   description: Text("Check back when games are in progress."))
                .foregroundStyle(.secondary)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(matchMonitor.liveMatches) { match in
                        AppMatchCard(match: match, overlayManager: overlayManager)
                    }
                }
                .padding(20)
            }
            .refreshable { await matchMonitor.forceRefresh() }
        }
    }
}

// MARK: - Today

struct AppTodayView: View {
    var matchMonitor: MatchMonitor
    var overlayManager: OverlayManager

    private var sortedGroups: [LeagueGroup] {
        matchMonitor.leagueGroups.sorted { a, b in
            let aPriority = MatchMonitor.priorityLeagueIDs.contains(a.id)
            let bPriority = MatchMonitor.priorityLeagueIDs.contains(b.id)
            if aPriority != bPriority { return aPriority }
            return a.name < b.name
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Error banner — shown whenever there's a problem but data already exists
            if let error = matchMonitor.lastError, !matchMonitor.leagueGroups.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") { Task { await matchMonitor.forceRefresh() } }
                        .buttonStyle(.plain)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))

                Divider().opacity(0.3)
            }

            if matchMonitor.leagueGroups.isEmpty {
                if let error = matchMonitor.lastError {
                    RetryableErrorView(message: error) {
                        Task { await matchMonitor.forceRefresh() }
                    }
                } else {
                    ContentUnavailableView("No Matches Today", systemImage: "calendar",
                                           description: Text("Add favourite leagues in Settings to see today's schedule."))
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: .sectionHeaders) {
                        ForEach(sortedGroups) { group in
                            AppLeagueSection(group: group,
                                             liveMatches: matchMonitor.liveMatches,
                                             overlayManager: overlayManager)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await matchMonitor.forceRefresh() }
            }
        }
    }
}

private struct AppLeagueSection: View {
    let group: LeagueGroup
    let liveMatches: [LiveMatch]
    var overlayManager: OverlayManager
    @State private var isExpanded = true

    /// Matches in this group that are NOT currently live (live ones move to Live Now).
    /// Finished matches stay here with FT score so the schedule feels complete.
    private var scheduledMatches: [LiveMatch] {
        group.matches.filter { match in
            !liveMatches.contains { $0.id == match.id }
        }
    }

    @ViewBuilder
    var body: some View {
        // If every match in the group is currently live, hide the whole section —
        // they're already visible in Live Now.
        if !scheduledMatches.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // League header
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        LeagueBadge(size: 22)

                        Text(group.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("\(scheduledMatches.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 6) {
                        ForEach(scheduledMatches) { match in
                            AppMatchRow(match: match, isLive: false, overlayManager: overlayManager)
                        }
                    }
                    .padding(.leading, 6)
                }
            }
        }
    }
}

private struct AppMatchRow: View {
    let match: LiveMatch
    let isLive: Bool
    var overlayManager: OverlayManager

    var body: some View {
        HStack(spacing: 12) {
            // Home team
            HStack(spacing: 8) {
                TeamBadge(size: 20, teamName: match.homeTeam.name)

                Text(match.homeTeam.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)

            // Score / time
            Group {
                if match.status.isLive || match.status.isFinished {
                    HStack(spacing: 4) {
                        Text("\(match.homeScore)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                        Text("-")
                            .foregroundStyle(.secondary)
                        Text("\(match.awayScore)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                    }
                } else {
                    Text(formatKickoff(match.kickoffDate))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, alignment: .center)

            // Away team
            HStack(spacing: 8) {
                TeamBadge(size: 20, teamName: match.awayTeam.name)

                Text(match.awayTeam.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            // Status / open button
            HStack(spacing: 8) {
                if isLive {
                    Text(match.clock)
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                } else if match.status.isFinished {
                    Text("FT")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Button {
                    overlayManager.openOverlay(for: match)
                } label: {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(isLive ? 0.07 : 0.03), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            isLive
                ? RoundedRectangle(cornerRadius: 8).strokeBorder(.red.opacity(0.25), lineWidth: 1)
                : nil
        )
    }

    private func formatKickoff(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Live Match Card (grid card for Live Now section)

struct AppMatchCard: View {
    let match: LiveMatch
    var overlayManager: OverlayManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // League + clock
            HStack {
                Text(match.leagueName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(match.clock)
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.red, in: Capsule())
            }

            // Teams + scores
            VStack(spacing: 8) {
                teamRow(team: match.homeTeam, score: match.homeScore)
                teamRow(team: match.awayTeam, score: match.awayScore)
            }

            // Footer: SOG + open button
            HStack {
                if let sog = match.shotsOnTarget {
                    Text("SOG \(sog.home)–\(sog.away)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                if let poss = match.possession {
                    Text("·")
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("\(poss.home)% poss")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    overlayManager.openOverlay(for: match)
                } label: {
                    Label("Overlay", systemImage: "pip.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.7), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private func teamRow(team: TeamInfo, score: Int) -> some View {
        HStack(spacing: 10) {
            TeamBadge(size: 28, teamName: team.name)

            Text(team.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)

            Spacer()

            Text("\(score)")
                .font(.system(size: 20, weight: .bold).monospacedDigit())
        }
    }
}

// MARK: - Standings

struct AppStandingsView: View {
    @Query(sort: \FavoriteLeague.name) private var favoriteLeagues: [FavoriteLeague]

    @State private var selectedLeagueID: Int? = nil
    @State private var season: Int = APIEndpoints.currentSeason
    @State private var standings: [[StandingEntry]] = []
    @State private var leagueName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var standingsTab: StandingsTab = .table
    @State private var resolvedSeason: Int? = nil   // non-nil when we fell back to a different year

    private var isKnockoutLeague: Bool {
        guard let id = selectedLeagueID else { return false }
        return knockoutLeagueIDs.contains(id)
    }

    // Known edition years for tournaments that don't run every season.
    // Add the next edition year here once announced.
    private static let tournamentEditions: [Int: [Int]] = [
        1:  [2026, 2022, 2018, 2014, 2010, 2006],   // FIFA World Cup
        4:  [2024, 2020, 2016, 2012, 2008, 2004],   // UEFA Euros
        6:  [2023, 2019, 2015, 2011, 2007],          // FIFA Women's World Cup
        9:  [2024, 2021, 2019, 2016, 2015, 2011],   // Copa América
    ]

    // Leagues that use a single calendar year as their season (e.g. MLS 2025, not 2025/26).
    static let calendarYearLeagues: Set<Int> = [
        253,  // MLS
        262,  // Liga MX
        71,   // Brazilian Série A
        72,   // Brazilian Série B
        11,   // CONMEBOL Libertadores
        13,   // CONMEBOL Sudamericana
        239,  // USL Championship
    ]

    // Season options shown in the picker — tournament editions for known comps,
    // single year for calendar-year leagues, standard sliding window for the rest.
    private var activeSeasonOptions: [(label: String, value: Int)] {
        guard let id = selectedLeagueID else {
            let year = APIEndpoints.currentSeason
            return [
                ("\(year)/\(String(year + 1).suffix(2))", year),
                ("\(year - 1)/\(String(year).suffix(2))", year - 1)
            ]
        }
        if let editions = Self.tournamentEditions[id] {
            return editions.map { (String($0), $0) }
        }
        let calYear = Calendar.current.component(.year, from: Date())
        if Self.calendarYearLeagues.contains(id) {
            return [calYear, calYear - 1, calYear - 2].map { (String($0), $0) }
        }
        let year = APIEndpoints.currentSeason
        return [
            ("\(year)/\(String(year + 1).suffix(2))", year),
            ("\(year - 1)/\(String(year).suffix(2))", year - 1)
        ]
    }

    /// Returns the correct default season when switching to a league,
    /// so the picker always has a valid selection and never shows "...".
    private func defaultSeason(for leagueID: Int) -> Int {
        let calYear = Calendar.current.component(.year, from: Date())
        if let editions = Self.tournamentEditions[leagueID] { return editions[0] }
        if Self.calendarYearLeagues.contains(leagueID) { return calYear }
        return APIEndpoints.currentSeason
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Text("Standings")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Spacer()

                // Season picker
                Picker("Season", selection: $season) {
                    ForEach(activeSeasonOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 120)

                // League picker
                Picker("League", selection: $selectedLeagueID) {
                    Text("Select League").tag(nil as Int?)
                    ForEach(favoriteLeagues) { league in
                        Text(league.name).tag(Optional(league.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 180)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider().opacity(0.2)

            // Tab bar — only shown for leagues with group + knockout stages
            if isKnockoutLeague {
                Picker("", selection: $standingsTab) {
                    ForEach(StandingsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Divider().opacity(0.2)
            }

            // Fallback season banner
            if let resolved = resolvedSeason, resolved != season {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    Text("No data for the selected season — showing \(String(resolved)) instead")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))

                Divider().opacity(0.2)
            }

            // Content
            if favoriteLeagues.isEmpty {
                ContentUnavailableView("No Favourite Leagues",
                                       systemImage: "list.number",
                                       description: Text("Add leagues in Settings to view standings."))
                    .foregroundStyle(.secondary)
            } else if selectedLeagueID == nil {
                ContentUnavailableView("Pick a League",
                                       systemImage: "list.number",
                                       description: Text("Use the dropdown above to select a league."))
                    .foregroundStyle(.secondary)
            } else if standingsTab == .knockout, let id = selectedLeagueID {
                AppKnockoutView(leagueID: id, season: season)
            } else if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let err = errorMessage {
                RetryableErrorView(message: err) {
                    guard let id = selectedLeagueID else { return }
                    Task { await load(leagueID: id, season: season) }
                }
            } else if standings.isEmpty || standings.allSatisfy({ $0.isEmpty }) {
                ContentUnavailableView("No Data",
                                       systemImage: "list.number",
                                       description: Text("Standings not available for this selection."))
                    .foregroundStyle(.secondary)
            } else {
                standingsTable
            }
        }
        .onChange(of: selectedLeagueID) { _, id in
            standingsTab = .table
            resolvedSeason = nil
            guard let id else { return }
            // If switching to a tournament league, jump to its most recent edition
            season = defaultSeason(for: id)
            Task { await load(leagueID: id, season: season) }
        }
        .onChange(of: season) { _, s in
            resolvedSeason = nil
            guard let id = selectedLeagueID else { return }
            Task { await load(leagueID: id, season: s) }
        }
        .onAppear {
            if selectedLeagueID == nil, let first = favoriteLeagues.first {
                selectedLeagueID = first.id
            }
        }
    }

    private var standingsTable: some View {
        let multiGroup = standings.count > 1
        return ScrollView {
            VStack(spacing: multiGroup ? 20 : 0) {
                ForEach(Array(standings.enumerated()), id: \.offset) { _, group in
                    VStack(spacing: 0) {
                        // Group header (only shown when multiple groups exist)
                        if multiGroup, let groupName = group.first?.group {
                            Text(groupName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                                .padding(.bottom, 6)
                        }

                        // Column headers
                        HStack {
                            Text("#").frame(width: 28, alignment: .center)
                            Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                            Text("MP").frame(width: 32, alignment: .center)
                            Text("W").frame(width: 28, alignment: .center)
                            Text("D").frame(width: 28, alignment: .center)
                            Text("L").frame(width: 28, alignment: .center)
                            Text("GD").frame(width: 36, alignment: .center)
                            Text("Pts").frame(width: 36, alignment: .center)
                            if !multiGroup {
                                Text("Form").frame(width: 72, alignment: .trailing)
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                        Divider().opacity(0.2)

                        ForEach(Array(group.enumerated()), id: \.element.id) { index, entry in
                            StandingRow(entry: entry, index: index, total: group.count, showForm: !multiGroup)
                            if index < group.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                                    .opacity(0.1)
                            }
                        }
                    }
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: multiGroup ? 10 : 0))
                    .overlay {
                        if multiGroup {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        }
                    }
                    .padding(.horizontal, multiGroup ? 12 : 0)
                }
            }
            .padding(.bottom, 16)
            .padding(.top, multiGroup ? 8 : 0)
        }
    }

    private func load(leagueID: Int, season: Int) async {
        isLoading = true
        errorMessage = nil
        standings = []
        resolvedSeason = nil

        // Order of years to try:
        // 1. The user-selected season (most likely to be right for domestic leagues)
        // 2. The current calendar year (catches WC 2026, Euros 2024, etc. when picker shows a different year)
        // 3. Walk backwards from the selected season
        // This means a domestic league like Bundesliga finds its data immediately on step 1,
        // while the World Cup falls through to step 2 and finds 2026 data.
        let calendarYear = Calendar.current.component(.year, from: Date())
        var yearsToTry = [season]
        if calendarYear != season { yearsToTry.append(calendarYear) }
        for i in 1..<8 {
            let y = season - i
            if !yearsToTry.contains(y) { yearsToTry.append(y) }
        }

        for tryYear in yearsToTry {
            do {
                let result = try await APIClient.shared.fetchStandings(leagueID: leagueID, season: tryYear)
                let fetched = result.first?.league.standings ?? []
                if !fetched.isEmpty {
                    standings = fetched
                    leagueName = result.first?.league.name ?? ""
                    if tryYear != season { resolvedSeason = tryYear }
                    break
                }
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }

        isLoading = false
    }
}

private struct StandingRow: View {
    let entry: StandingEntry
    let index: Int
    let total: Int
    var showForm: Bool = true

    // Rough zone colour based on description text — adapt to your leagues
    private var zoneColor: Color? {
        guard let desc = entry.description?.lowercased() else { return nil }
        if desc.contains("champions league") { return .blue }
        if desc.contains("europa") { return .orange }
        if desc.contains("relegation") || desc.contains("relega") { return .red }
        return nil
    }

    var body: some View {
        HStack {
            // Zone indicator + rank
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(zoneColor ?? .clear)
                    .frame(width: 3, height: 22)

                Text("\(entry.rank)")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .center)
            }
            .frame(width: 32)

            // Team logo + name
            HStack(spacing: 8) {
                TeamBadge(size: 20, teamName: entry.team.name)

                Text(entry.team.name)
                    .font(.system(size: 13, weight: index < 4 ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(entry.all.played)").frame(width: 32, alignment: .center)
            Text("\(entry.all.win)").frame(width: 28, alignment: .center)
            Text("\(entry.all.draw)").frame(width: 28, alignment: .center)
            Text("\(entry.all.lose)").frame(width: 28, alignment: .center)

            Text(entry.goalsDiff >= 0 ? "+\(entry.goalsDiff)" : "\(entry.goalsDiff)")
                .foregroundStyle(entry.goalsDiff > 0 ? .green : entry.goalsDiff < 0 ? .red : .secondary)
                .frame(width: 36, alignment: .center)

            Text("\(entry.points)")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 36, alignment: .center)

            // Form string as coloured dots (hidden in multi-group mode)
            if showForm {
                if let form = entry.form {
                    HStack(spacing: 3) {
                        ForEach(Array(form.suffix(5)), id: \.self) { ch in
                            Circle()
                                .fill(formColor(ch))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(width: 72, alignment: .trailing)
                } else {
                    Spacer().frame(width: 72)
                }
            }
        }
        .font(.system(size: 13).monospacedDigit())
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
    }

    private func formColor(_ char: Character) -> Color {
        switch char {
        case "W": return .green
        case "D": return .orange
        case "L": return .red
        default:  return .secondary
        }
    }
}

// MARK: - Knockout View

struct AppKnockoutView: View {
    let leagueID: Int
    let season: Int

    struct KnockoutRound: Identifiable {
        let id: String          // round name, e.g. "Round of 16"
        let matches: [LiveMatch]
    }

    @State private var rounds: [KnockoutRound] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resolvedSeason: Int? = nil

    // Keywords that identify a knockout round vs a group/league stage round
    private static let knockoutKeywords = [
        "round of", "quarter", "semi", "final",
        "play-off", "playoff", "3rd place", "third place"
    ]

    private func isKnockoutRound(_ name: String) -> Bool {
        let lower = name.lowercased()
        return Self.knockoutKeywords.contains { lower.contains($0) }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = errorMessage {
                RetryableErrorView(message: err) { Task { await load() } }
            } else if rounds.isEmpty {
                ContentUnavailableView(
                    "No Knockout Matches",
                    systemImage: "arrow.trianglehead.branch",
                    description: Text("Knockout stage matches will appear here once the group stage concludes.")
                )
                .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    // Fallback season banner
                    if let resolved = resolvedSeason, resolved != season {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.orange)
                                .font(.system(size: 12))
                            Text("No data for the selected season — showing \(String(resolved)) instead")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.08))

                        Divider().opacity(0.2)
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(rounds) { round in
                                KnockoutRoundSection(roundName: round.id, matches: round.matches)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        // Re-fetches automatically whenever league or season changes
        .task(id: "\(leagueID)-\(season)") { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        rounds = []
        resolvedSeason = nil

        let calendarYear = Calendar.current.component(.year, from: Date())
        var yearsToTry = [season]
        if calendarYear != season { yearsToTry.append(calendarYear) }
        for i in 1..<8 {
            let y = season - i
            if !yearsToTry.contains(y) { yearsToTry.append(y) }
        }

        for tryYear in yearsToTry {
            do {
                let allRounds = try await APIClient.shared.fetchRounds(leagueID: leagueID, season: tryYear)
                let knockoutRoundNames = allRounds.filter { isKnockoutRound($0) }
                guard !knockoutRoundNames.isEmpty else {
                    continue   // no knockout rounds this year, try previous
                }

                // Found a year with knockout rounds — fetch the fixtures
                if tryYear != season { resolvedSeason = tryYear }

                var result: [KnockoutRound] = []
                for roundName in knockoutRoundNames {
                    let fixtures = try await APIClient.shared.fetchFixturesByRound(
                        leagueID: leagueID, season: tryYear, round: roundName
                    )
                    if !fixtures.isEmpty {
                        let matches = fixtures
                            .map { LiveMatch(from: $0) }
                            .sorted { $0.kickoffDate < $1.kickoffDate }
                        result.append(KnockoutRound(id: roundName, matches: matches))
                    }
                }
                rounds = result
                break   // found data — stop walking back
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }

        isLoading = false
    }
}

private struct KnockoutRoundSection: View {
    let roundName: String
    let matches: [LiveMatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Round header
            Text(roundName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 6) {
                ForEach(matches) { match in
                    KnockoutMatchRow(match: match)
                }
            }
            .padding(.leading, 6)
        }
    }
}

private struct KnockoutMatchRow: View {
    let match: LiveMatch

    // The API sometimes returns "PEN" (live penalty status) for historical
    // matches that ended in a shootout. Treat any match whose kickoff was
    // more than 3 hours ago as effectively finished.
    private var effectivelyFinished: Bool {
        match.status.isFinished
            || match.status == .penalties
            || match.status == .extraTime
            && Date().timeIntervalSince(match.kickoffDate) > 3 * 3600
    }

    private var trulyLive: Bool {
        match.status.isLive && !effectivelyFinished
    }

    // "FT", "AET", or "PSO" label for finished matches
    private var finishedLabel: String {
        switch match.status {
        case .finishedPEN, .penalties: return "PSO"
        case .finishedAET, .extraTime: return "AET"
        default:                        return "FT"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Date
            Text(formatDate(match.kickoffDate))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            // Home team (logo + name, right-aligned)
            HStack(spacing: 6) {
                Text(match.homeTeam.name)
                    .font(.system(size: 13, weight: match.homeTeam.winner == true ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(match.homeTeam.winner == true ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                TeamBadge(size: 20, teamName: match.homeTeam.name)
            }
            .frame(maxWidth: .infinity)

            // Score / kickoff time
            Group {
                if effectivelyFinished || trulyLive {
                    HStack(spacing: 4) {
                        Text("\(match.homeScore)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(match.homeTeam.winner == true ? .primary : .secondary)
                        Text("–")
                            .foregroundStyle(.secondary)
                        Text("\(match.awayScore)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(match.awayTeam.winner == true ? .primary : .secondary)
                    }
                } else {
                    Text(formatTime(match.kickoffDate))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, alignment: .center)

            // Away team (logo + name, left-aligned)
            HStack(spacing: 6) {
                TeamBadge(size: 20, teamName: match.awayTeam.name)

                Text(match.awayTeam.name)
                    .font(.system(size: 13, weight: match.awayTeam.winner == true ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(match.awayTeam.winner == true ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            // Status column — live clock, or FT/AET/PSO with optional penalty score
            Group {
                if trulyLive {
                    Text(match.clock)
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                } else if effectivelyFinished {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(finishedLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        // Penalty shootout score, e.g. "4–2 pens"
                        if finishedLabel == "PSO", let pen = match.penaltyScore {
                            Text("\(pen.home)–\(pen.away) pens")
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if match.status == .postponed {
                    Text("PST")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                } else {
                    Color.clear
                }
            }
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Color.primary.opacity(trulyLive ? 0.07 : 0.03),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            trulyLive
                ? RoundedRectangle(cornerRadius: 8).strokeBorder(.red.opacity(0.25), lineWidth: 1)
                : nil
        )
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Season Stats

struct AppSeasonStatsView: View {
    @Query(sort: \FavoriteLeague.name) private var favoriteLeagues: [FavoriteLeague]

    @State private var statType: SeasonStatType = .topScorers
    @State private var selectedLeagueID: Int? = nil
    @State private var season: Int = APIEndpoints.currentSeason
    @State private var entries: [TopScorerEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var seasonOptions: [(label: String, value: Int)] {
        let calYear = Calendar.current.component(.year, from: Date())
        if let id = selectedLeagueID, AppStandingsView.calendarYearLeagues.contains(id) {
            return [calYear, calYear - 1, calYear - 2].map { (String($0), $0) }
        }
        let year = APIEndpoints.currentSeason
        return [
            ("\(year)/\(String(year + 1).suffix(2))", year),
            ("\(year - 1)/\(String(year).suffix(2))", year - 1)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Text("Season Stats")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                // Sub-type picker
                Picker("", selection: $statType) {
                    ForEach(SeasonStatType.allCases, id: \.self) { type in
                        Text("\(type.icon) \(type.rawValue)").tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(.yellow)
                .frame(width: 150)

                Spacer()

                Picker("Season", selection: $season) {
                    ForEach(seasonOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 120)

                Picker("League", selection: $selectedLeagueID) {
                    Text("Select League").tag(nil as Int?)
                    ForEach(favoriteLeagues) { league in
                        Text(league.name).tag(Optional(league.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 180)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider().opacity(0.2)

            if favoriteLeagues.isEmpty {
                ContentUnavailableView("No Favourite Leagues",
                                       systemImage: "chart.bar.fill",
                                       description: Text("Add leagues in Settings to view season stats."))
                    .foregroundStyle(.secondary)
            } else if selectedLeagueID == nil {
                ContentUnavailableView("Pick a League",
                                       systemImage: "chart.bar.fill",
                                       description: Text("Use the dropdown above to select a league."))
                    .foregroundStyle(.secondary)
            } else if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let err = errorMessage {
                RetryableErrorView(message: err) { reload() }
            } else if entries.isEmpty {
                ContentUnavailableView("No Data",
                                       systemImage: "chart.bar.fill",
                                       description: Text("Stats not available for this selection."))
                    .foregroundStyle(.secondary)
            } else {
                statsList
            }
        }
        .onChange(of: statType) { _, _ in reload() }
        .onChange(of: selectedLeagueID) { _, id in
            // Reset season to a valid value for the new league before reloading
            if let id {
                let calYear = Calendar.current.component(.year, from: Date())
                if AppStandingsView.calendarYearLeagues.contains(id) {
                    season = calYear
                } else {
                    season = APIEndpoints.currentSeason
                }
            }
            reload()
        }
        .onChange(of: season) { _, _ in reload() }
        .onAppear {
            if selectedLeagueID == nil, let first = favoriteLeagues.first {
                selectedLeagueID = first.id
            }
        }
    }

    private var statsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Column headers — primary column is bolded based on stat type
                HStack {
                    Text("#").frame(width: 30, alignment: .center)
                    Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Club").frame(width: 130, alignment: .leading)
                    Text(statType.primaryColumn)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .frame(width: 56, alignment: .center)
                    Text(statType == .topScorers ? "Assists" : "Goals")
                        .frame(width: 56, alignment: .center)
                    Text("Apps").frame(width: 45, alignment: .center)
                    Text("Rating").frame(width: 50, alignment: .center)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Divider().opacity(0.2)

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    ScorerRow(entry: entry, rank: index + 1, statType: statType, leagueID: selectedLeagueID)
                    if index < entries.count - 1 {
                        Divider()
                            .padding(.leading, 20)
                            .opacity(0.1)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func reload() {
        guard let id = selectedLeagueID else { return }
        Task { await load(leagueID: id, season: season, type: statType) }
    }

    private func load(leagueID: Int, season: Int, type: SeasonStatType) async {
        isLoading = true
        errorMessage = nil
        entries = []
        do {
            switch type {
            case .topScorers: entries = try await APIClient.shared.fetchTopScorers(leagueID: leagueID, season: season)
            case .topAssists: entries = try await APIClient.shared.fetchTopAssists(leagueID: leagueID, season: season)
            case .topRatings: entries = try await APIClient.shared.fetchTopRatings(leagueID: leagueID, season: season)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ScorerRow: View {
    let entry: TopScorerEntry
    let rank: Int
    var statType: SeasonStatType = .topScorers
    var leagueID: Int? = nil

    var stats: TopScorerStatistics? {
        if let id = leagueID,
           let match = entry.statistics.first(where: { $0.league?.id == id }) {
            return match
        }
        return entry.statistics.first
    }

    // Primary value highlighted based on stat type
    private var primaryValue: String {
        switch statType {
        case .topScorers: return "\(stats?.goals.total ?? 0)"
        case .topAssists: return "\(stats?.goals.assists ?? 0)"
        case .topRatings:
            if let r = stats?.games.rating, let val = Double(r) {
                return String(format: "%.1f", val)
            }
            return "—"
        }
    }

    // Secondary value (the other one)
    private var secondaryValue: String {
        switch statType {
        case .topScorers: return "\(stats?.goals.assists ?? 0)"
        case .topAssists, .topRatings: return "\(stats?.goals.total ?? 0)"
        }
    }

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .center)

            // Player initials avatar (avoids player image-rights issues)
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .overlay(
                        Text(initials(for: entry.player.name))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    )
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.player.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let nat = entry.player.nationality {
                        Text(nat)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Club
            if let team = stats?.team {
                HStack(spacing: 6) {
                    TeamBadge(size: 18)
                    Text(team.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .frame(width: 130, alignment: .leading)
            } else {
                Spacer().frame(width: 130)
            }

            // Primary stat (bold, highlighted)
            Text(primaryValue)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 56, alignment: .center)

            // Secondary stat
            Text(secondaryValue)
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .center)

            Text("\(stats?.games.appearences ?? 0)")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .center)

            // Rating (always shown, dimmed when not the primary stat)
            if let ratingStr = stats?.games.rating, let rating = Double(ratingStr) {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 12, weight: statType == .topRatings ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(statType == .topRatings ? ratingColor(rating) : .secondary)
                    .frame(width: 50, alignment: .center)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(rank % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
    }

    private func ratingColor(_ r: Double) -> Color {
        if r >= 8.5 { return .yellow }
        if r >= 7.0 { return .green }
        if r < 6.0  { return .orange }
        return .secondary
    }

    /// "Mohamed Salah" → "MS",  "Erling Haaland" → "EH",  "Vinícius Jr." → "VJ"
    private func initials(for name: String) -> String {
        let parts = name
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let letters = parts.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }
        return letters.joined()
    }
}
