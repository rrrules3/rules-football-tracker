//
//  FixtureCache.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation

/* Persists today's fetched fixtures so we can skip the startup API call
 if we've already fetched them earlier the same day. */
enum FixtureCache {
    private static let fixturesKey = "FixtureCache.fixtures"
    private static let dateKey = "FixtureCache.date"

    // Save today's fixtures to disk along with the date they were fetched.
    static func save(_ fixtures: [FixtureResponse]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(fixtures) else { return }
        UserDefaults.standard.set(data, forKey: fixturesKey)
        UserDefaults.standard.set(todayString(), forKey: dateKey)
    }

    // Load cached fixtures if they were saved on the current date.
    // Returns nil if cache is stale or missing.
    static func loadIfFresh() -> [FixtureResponse]? {
        guard let cachedDate = UserDefaults.standard.string(forKey: dateKey),
              cachedDate == todayString(),
              let data = UserDefaults.standard.data(forKey: fixturesKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode([FixtureResponse].self, from: data)
    }

    // Clear the cache — used when switching favorites or manually refreshing.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: fixturesKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
