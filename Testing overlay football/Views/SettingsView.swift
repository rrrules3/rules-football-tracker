//
//  SettingsView.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - Appearance

enum AppAppearance: String, CaseIterable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteTeam.name)   private var favoriteTeams: [FavoriteTeam]
    @Query(sort: \FavoriteLeague.name) private var favoriteLeagues: [FavoriteLeague]

    @AppStorage("appAppearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @State private var showingAddTeam   = false
    @State private var showingAddLeague = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Appearance
                SettingsSection(title: "Appearance", icon: "circle.lefthalf.filled", iconColor: .blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        Picker("", selection: $appearanceRaw) {
                            ForEach(AppAppearance.allCases, id: \.rawValue) { mode in
                                Text(mode.rawValue).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                        .onChange(of: appearanceRaw) { _, newValue in
                            NSApp.appearance = (AppAppearance(rawValue: newValue) ?? .system).nsAppearance
                        }
                    }
                }

                // MARK: Favourite Teams
                SettingsSection(title: "Favourite Teams", icon: "shield.fill", iconColor: .green) {
                    VStack(alignment: .leading, spacing: 0) {
                        if favoriteTeams.isEmpty {
                            HStack {
                                Image(systemName: "shield")
                                    .foregroundStyle(.secondary)
                                Text("No favourite teams yet")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                        } else {
                            ForEach(Array(favoriteTeams.enumerated()), id: \.element.id) { index, team in
                                HStack(spacing: 12) {
                                    TeamBadge(size: 22, teamName: team.name)

                                    Text(team.name)
                                        .font(.system(size: 14))

                                    Spacer()

                                    Button {
                                        modelContext.delete(team)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 4)

                                if index < favoriteTeams.count - 1 {
                                    Divider().opacity(0.4)
                                }
                            }
                        }

                        Divider().opacity(0.4)
                            .padding(.top, favoriteTeams.isEmpty ? 0 : 4)

                        Button {
                            showingAddTeam = true
                        } label: {
                            Label("Add Team", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .sheet(isPresented: $showingAddTeam) {
                            AddTeamSheet()
                        }
                    }
                }

                // MARK: Favourite Leagues
                SettingsSection(title: "Favourite Leagues", icon: "trophy.fill", iconColor: .orange) {
                    VStack(alignment: .leading, spacing: 0) {
                        if favoriteLeagues.isEmpty {
                            HStack {
                                Image(systemName: "trophy")
                                    .foregroundStyle(.secondary)
                                Text("No favourite leagues yet")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                        } else {
                            ForEach(Array(favoriteLeagues.enumerated()), id: \.element.id) { index, league in
                                HStack(spacing: 12) {
                                    LeagueBadge(size: 22)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(league.name)
                                            .font(.system(size: 14))
                                        Text(league.country)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        modelContext.delete(league)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 4)

                                if index < favoriteLeagues.count - 1 {
                                    Divider().opacity(0.4)
                                }
                            }
                        }

                        Divider().opacity(0.4)
                            .padding(.top, favoriteLeagues.isEmpty ? 0 : 4)

                        Button {
                            showingAddLeague = true
                        } label: {
                            Label("Add League", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .sheet(isPresented: $showingAddLeague) {
                            AddLeagueSheet()
                        }
                    }
                }

            }
            .padding(32)
            .frame(maxWidth: 680)   // comfortable reading width, centred in wide windows
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Toolbar header — matches Today / Standings style
        .safeAreaInset(edge: .top) {
            HStack {
                Text("Settings")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(alignment: .bottom) {
                Divider().opacity(0.2)
            }
        }
    }
}

// MARK: - Settings Section Card

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            // Card
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
        }
    }
}

// MARK: - Add Team Sheet

struct AddTeamSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FavoriteTeam.name) private var existingTeams: [FavoriteTeam]

    @State private var searchText = ""
    @State private var searchResults: [TeamSearchResponse] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let popularTeams: [(id: Int, name: String, logo: String)] = [
        (42,  "Arsenal",             "https://media.api-sports.io/football/teams/42.png"),
        (33,  "Manchester United",   "https://media.api-sports.io/football/teams/33.png"),
        (50,  "Manchester City",     "https://media.api-sports.io/football/teams/50.png"),
        (40,  "Liverpool",           "https://media.api-sports.io/football/teams/40.png"),
        (49,  "Chelsea",             "https://media.api-sports.io/football/teams/49.png"),
        (47,  "Tottenham",           "https://media.api-sports.io/football/teams/47.png"),
        (529, "Barcelona",           "https://media.api-sports.io/football/teams/529.png"),
        (541, "Real Madrid",         "https://media.api-sports.io/football/teams/541.png"),
        (157, "Bayern Munich",       "https://media.api-sports.io/football/teams/157.png"),
        (85,  "Paris Saint-Germain", "https://media.api-sports.io/football/teams/85.png"),
        (496, "Juventus",            "https://media.api-sports.io/football/teams/496.png"),
        (489, "AC Milan",            "https://media.api-sports.io/football/teams/489.png"),
        (505, "Inter Milan",         "https://media.api-sports.io/football/teams/505.png"),
        (165, "Borussia Dortmund",   "https://media.api-sports.io/football/teams/165.png"),
        (34,  "Newcastle",           "https://media.api-sports.io/football/teams/34.png"),
        (66,  "Aston Villa",         "https://media.api-sports.io/football/teams/66.png"),
        (51,  "Brighton",            "https://media.api-sports.io/football/teams/51.png"),
        (48,  "West Ham",            "https://media.api-sports.io/football/teams/48.png"),
    ]

    private var existingIDs: Set<Int> { Set(existingTeams.map(\.id)) }
    private var isLiveSearch: Bool { searchText.count >= 2 }

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Favourite Team")
                .font(.headline)

            TextField("Search any team…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, query in
                    searchTask?.cancel()
                    guard query.count >= 2 else {
                        searchResults = []
                        isSearching = false
                        return
                    }
                    isSearching = true
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        do {
                            let results = try await APIClient.shared.searchTeams(query: query)
                            guard !Task.isCancelled else { return }
                            searchResults = results
                                .filter { !existingIDs.contains($0.team.id) }
                                .sorted { a, b in
                                    // Exact name match first
                                    let aExact = a.team.name.lowercased() == query.lowercased()
                                    let bExact = b.team.name.lowercased() == query.lowercased()
                                    if aExact != bExact { return aExact }
                                    // National teams before clubs
                                    let aNational = a.team.national == true
                                    let bNational = b.team.national == true
                                    if aNational != bNational { return aNational }
                                    return a.team.name < b.team.name
                                }
                        } catch { }
                        isSearching = false
                    }
                }

            if isSearching {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Searching…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            if isLiveSearch {
                if !isSearching && searchResults.isEmpty {
                    Text("No teams found for \"\(searchText)\"")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    List(searchResults, id: \.team.id) { result in
                        teamRow(id: result.team.id, name: result.team.name, logo: result.team.logo)
                    }
                    .frame(minHeight: 200)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("POPULAR TEAMS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    List(popularTeams.filter { !existingIDs.contains($0.id) }, id: \.id) { team in
                        teamRow(id: team.id, name: team.name, logo: team.logo)
                    }
                    .frame(minHeight: 200)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
            }
        }
        .padding()
        .frame(width: 380, height: 460)
    }

    @ViewBuilder
    private func teamRow(id: Int, name: String, logo: String) -> some View {
        HStack {
            TeamBadge(size: 24, teamName: name)
            Text(name)
            Spacer()
            Button("Add") {
                let fav = FavoriteTeam(id: id, name: name, logoURL: logo, leagueID: 0)
                modelContext.insert(fav)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

// MARK: - Add League Sheet

struct AddLeagueSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FavoriteLeague.name) private var existingLeagues: [FavoriteLeague]

    private let popularLeagues: [(id: Int, name: String, logo: String, country: String)] = [
        (39,  "Premier League",      "https://media.api-sports.io/football/leagues/39.png",  "England"),
        (140, "La Liga",             "https://media.api-sports.io/football/leagues/140.png", "Spain"),
        (78,  "Bundesliga",          "https://media.api-sports.io/football/leagues/78.png",  "Germany"),
        (135, "Serie A",             "https://media.api-sports.io/football/leagues/135.png", "Italy"),
        (61,  "Ligue 1",             "https://media.api-sports.io/football/leagues/61.png",  "France"),
        (2,   "Champions League",    "https://media.api-sports.io/football/leagues/2.png",   "Europe"),
        (3,   "Europa League",       "https://media.api-sports.io/football/leagues/3.png",   "Europe"),
        (848, "Conference League",   "https://media.api-sports.io/football/leagues/848.png", "Europe"),
        (94,  "Liga Portugal",       "https://media.api-sports.io/football/leagues/94.png",  "Portugal"),
        (253, "MLS",                 "https://media.api-sports.io/football/leagues/253.png", "USA & Canada"),
        (307, "Saudi Pro League",    "https://media.api-sports.io/football/leagues/307.png", "Saudi Arabia"),
        (323, "Indian Super League", "https://media.api-sports.io/football/leagues/323.png", "India"),
        (1,   "World Cup",           "https://media.api-sports.io/football/leagues/1.png",   "World"),
        (4,   "Euros",               "https://media.api-sports.io/football/leagues/4.png",   "Europe"),
        (9,   "Copa America",        "https://media.api-sports.io/football/leagues/9.png",   "South America"),
    ]

    private var existingIDs: Set<Int> { Set(existingLeagues.map(\.id)) }

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Favourite League")
                .font(.headline)

            List(popularLeagues.filter { !existingIDs.contains($0.id) }, id: \.id) { league in
                leagueRow(id: league.id, name: league.name,
                          logo: league.logo, country: league.country)
            }
            .frame(minHeight: 300)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
            }
        }
        .padding()
        .frame(width: 380, height: 420)
    }

    @ViewBuilder
    private func leagueRow(id: Int, name: String, logo: String, country: String) -> some View {
        HStack {
            LeagueBadge(size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                Text(country).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Add") {
                let fav = FavoriteLeague(id: id, name: name, logoURL: logo, country: country)
                modelContext.insert(fav)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}
