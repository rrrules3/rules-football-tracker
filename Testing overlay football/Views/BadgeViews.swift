//
//  BadgeViews.swift
//  Testing overlay football
//
//  Placeholder badge components. Club crests and league logos are replaced
//  with SF Symbol placeholders (trademark concern). National teams get a
//  flag emoji instead — those are plain Unicode and carry no IP issues.
//

import SwiftUI

// MARK: - National Team Flag Lookup

enum NationalTeamFlags {
    /// Returns a flag emoji for a national team name, or nil for club sides.
    /// Uses Swift's Locale API to cover all ~250 countries automatically.
    /// Manual overrides handle API-Football's non-standard names and UK home nations.
    static func flag(for teamName: String) -> String? {
        // 1. Manual overrides first (subdivision flags + API-Football quirks)
        if let f = overrides[teamName] { return f }
        // 2. Try Locale reverse-lookup → ISO code → emoji
        if let iso = nameToISO[teamName] { return flagEmoji(iso) }
        return nil
    }

    // Convert a 2-letter ISO 3166-1 alpha-2 code into a flag emoji.
    // Each letter maps to a Unicode Regional Indicator (U+1F1E6…U+1F1FF).
    private static func flagEmoji(_ isoCode: String) -> String {
        isoCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)   // 127397 = 0x1F1E6 - 65 ('A')
        }.map(String.init).joined()
    }

    // Built once at first use: English country name → ISO 3166-1 alpha-2 code.
    private static let nameToISO: [String: String] = {
        let locale = Locale(identifier: "en_US")
        var dict: [String: String] = [:]
        for region in Locale.Region.isoRegions {
            let code = region.identifier
            if let name = locale.localizedString(forRegionCode: code) {
                dict[name] = code
            }
        }
        return dict
    }()

    // API-Football uses non-standard names for some teams, and the UK home nations
    // need subdivision tag-sequence emoji that can't be derived from ISO codes.
    private static let overrides: [String: String] = [
        // UK home nations (tag-sequence emoji, not ISO flags)
        "England":              "🏴󠁧󠁢󠁥󠁮󠁧󠁿",
        "Scotland":             "🏴󠁧󠁢󠁳󠁣󠁴󠁿",
        "Wales":                "🏴󠁧󠁢󠁷󠁬󠁳󠁿",
        "Northern Ireland":     "🇬🇧",
        // AFC non-standard names
        "Korea Republic":       "🇰🇷",
        "Korea DPR":            "🇰🇵",
        "China PR":             "🇨🇳",
        "Chinese Taipei":       "🇹🇼",
        "Palestine":            "🇵🇸",
        // CAF non-standard names
        "DR Congo":             "🇨🇩",
        "Congo DR":             "🇨🇩",
        "Ivory Coast":          "🇨🇮",
        // CONCACAF non-standard names
        "USA":                  "🇺🇸",
        "Trinidad & Tobago":    "🇹🇹",
        "Antigua and Barbuda":  "🇦🇬",
        "St. Kitts & Nevis":    "🇰🇳",
        "St. Lucia":            "🇱🇨",
        "St. Vincent & Grenadines": "🇻🇨",
        // Old/common names that Locale now lists under updated official names
        "Cape Verde":           "🇨🇻",   // Locale uses "Cabo Verde"
        "Cape Verde Islands":   "🇨🇻",   // API-Football variant
        "Czech Republic":       "🇨🇿",   // Locale uses "Czechia"
        "Macedonia":            "🇲🇰",   // Locale uses "North Macedonia"
        "Macau":                "🇲🇴",   // Locale uses "Macao SAR China"
        "Hong Kong":            "🇭🇰",   // Locale uses "Hong Kong SAR China"
        // Other common aliases
        "UAE":                  "🇦🇪",
        "Kosovo":               "🇽🇰",   // not an official ISO code but widely used
        "Republic of Ireland":  "🇮🇪",
        "Türkiye":              "🇹🇷",
        "Turkiye":              "🇹🇷",
        "Swaziland":            "🇸🇿",   // now Eswatini
    ]
}

// MARK: - Team Badge

/// Shows a flag emoji for national teams, or a generic shield for club sides.
/// Pass `teamName` whenever you have it — the flag lookup is a O(1) dictionary hit.
struct TeamBadge: View {
    var size: CGFloat = 24
    var teamName: String? = nil

    private var flag: String? {
        guard let name = teamName else { return nil }
        return NationalTeamFlags.flag(for: name)
    }

    var body: some View {
        if let flag {
            Text(flag)
                .font(.system(size: size * 0.82))
                .frame(width: size, height: size)
        } else {
            Image(systemName: "shield.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - League Badge

/// Generic trophy icon used wherever a league/competition logo would appear.
struct LeagueBadge: View {
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: "trophy.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
    }
}
