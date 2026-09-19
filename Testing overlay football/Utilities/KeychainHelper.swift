//
//  KeychainHelper.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation

nonisolated enum KeychainHelper {
    private static let key = "api_football_key"

    static func saveAPIKey(_ apiKey: String) {
        UserDefaults.standard.set(apiKey, forKey: key)
    }

    static func getAPIKey() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func deleteAPIKey() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
