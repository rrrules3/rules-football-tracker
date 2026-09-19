//
//  OnboardingView.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteTeam.name) private var favoriteTeams: [FavoriteTeam]
    @Query(sort: \FavoriteLeague.name) private var favoriteLeagues: [FavoriteLeague]

    @State private var currentStep = 0
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("⚽")
                    .font(.system(size: 48))
                Text("Football Overlay")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Follow live matches right from your menu bar")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Step content
            TabView(selection: $currentStep) {
                teamsStep.tag(0)
                leaguesStep.tag(1)
            }
            .tabViewStyle(.automatic)

            Divider()

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                }

                Spacer()

                Text("Step \(currentStep + 1) of 2")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if currentStep == 0 {
                    Button("Next") {
                        withAnimation { currentStep = 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Teams Step

    private var teamsStep: some View {
        OnboardingTeamsStep()
    }

    // MARK: - Leagues Step

    private var leaguesStep: some View {
        OnboardingLeaguesStep()
    }
}

// MARK: - Teams Step View

struct OnboardingTeamsStep: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteTeam.name) private var favoriteTeams: [FavoriteTeam]
    @State private var searchText = ""
    //Testing with big clubs for now, at least for favoriting
    private let sampleTeams: [(id: Int, name: String, logo: String, leagueID: Int)] = [
        (42, "Arsenal", "https://media.api-sports.io/football/teams/42.png", 39),
        (33, "Manchester United", "https://media.api-sports.io/football/teams/33.png", 39),
        (50, "Manchester City", "https://media.api-sports.io/football/teams/50.png", 39),
        (40, "Liverpool", "https://media.api-sports.io/football/teams/40.png", 39),
        (49, "Chelsea", "https://media.api-sports.io/football/teams/49.png", 39),
        (47, "Tottenham", "https://media.api-sports.io/football/teams/47.png", 39),
        (529, "Barcelona", "https://media.api-sports.io/football/teams/529.png", 140),
        (541, "Real Madrid", "https://media.api-sports.io/football/teams/541.png", 140),
        (157, "Bayern Munich", "https://media.api-sports.io/football/teams/157.png", 78),
        (85, "Paris Saint-Germain", "https://media.api-sports.io/football/teams/85.png", 61),
        (496, "Juventus", "https://media.api-sports.io/football/teams/496.png", 135),
        (489, "AC Milan", "https://media.api-sports.io/football/teams/489.png", 135),
        (505, "Inter Milan", "https://media.api-sports.io/football/teams/505.png", 135),
        (165, "Borussia Dortmund", "https://media.api-sports.io/football/teams/165.png", 78),
        (34, "Newcastle", "https://media.api-sports.io/football/teams/34.png", 39),
        (66, "Aston Villa", "https://media.api-sports.io/football/teams/66.png", 39),
        (51, "Brighton", "https://media.api-sports.io/football/teams/51.png", 39),
        (48, "West Ham", "https://media.api-sports.io/football/teams/48.png", 39),
    ]

    private var filteredTeams: [(id: Int, name: String, logo: String, leagueID: Int)] {
        let favoriteIDs = Set(favoriteTeams.map(\.id))
        let available = sampleTeams.filter { !favoriteIDs.contains($0.id) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick your favorite teams")
                .font(.headline)
                .padding(.horizontal)

            TextField("Search teams...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            // Selected teams
            if !favoriteTeams.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(favoriteTeams) { team in
                            HStack(spacing: 4) {
                                TeamBadge(size: 16, teamName: team.name)

                                Text(team.name)
                                    .font(.caption)

                                Button {
                                    modelContext.delete(team)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Available teams list
            List(filteredTeams, id: \.id) { team in
                HStack {
                    TeamBadge(size: 28, teamName: team.name)

                    Text(team.name)
                        .font(.body)

                    Spacer()

                    Button {
                        let favorite = FavoriteTeam(
                            id: team.id,
                            name: team.name,
                            logoURL: team.logo,
                            leagueID: team.leagueID
                        )
                        modelContext.insert(favorite)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Leagues Step View

struct OnboardingLeaguesStep: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteLeague.name) private var favoriteLeagues: [FavoriteLeague]
    @State private var searchText = ""

    private let sampleLeagues: [(id: Int, name: String, logo: String, country: String)] = [
        (39, "Premier League", "https://media.api-sports.io/football/leagues/39.png", "England"),
        (140, "La Liga", "https://media.api-sports.io/football/leagues/140.png", "Spain"),
        (78, "Bundesliga", "https://media.api-sports.io/football/leagues/78.png", "Germany"),
        (135, "Serie A", "https://media.api-sports.io/football/leagues/135.png", "Italy"),
        (61, "Ligue 1", "https://media.api-sports.io/football/leagues/61.png", "France"),
        (2, "Champions League", "https://media.api-sports.io/football/leagues/2.png", "World"),
        (3, "Europa League", "https://media.api-sports.io/football/leagues/3.png", "World"),
        (848, "Conference League", "https://media.api-sports.io/football/leagues/848.png", "World"),
        (94, "Primeira Liga", "https://media.api-sports.io/football/leagues/94.png", "Portugal"),
        (88, "Eredivisie", "https://media.api-sports.io/football/leagues/88.png", "Netherlands"),
    ]

    private var filteredLeagues: [(id: Int, name: String, logo: String, country: String)] {
        let favoriteIDs = Set(favoriteLeagues.map(\.id))
        let available = sampleLeagues.filter { !favoriteIDs.contains($0.id) }
        if searchText.isEmpty { return available }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick your favorite leagues")
                .font(.headline)
                .padding(.horizontal)

            TextField("Search leagues...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            // Selected leagues
            if !favoriteLeagues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(favoriteLeagues) { league in
                            HStack(spacing: 4) {
                                LeagueBadge(size: 16)

                                Text(league.name)
                                    .font(.caption)

                                Button {
                                    modelContext.delete(league)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Available leagues list
            List(filteredLeagues, id: \.id) { league in
                HStack {
                    LeagueBadge(size: 28)

                    VStack(alignment: .leading) {
                        Text(league.name)
                            .font(.body)
                        Text(league.country)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        let favorite = FavoriteLeague(
                            id: league.id,
                            name: league.name,
                            logoURL: league.logo,
                            country: league.country
                        )
                        modelContext.insert(favorite)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }
}
