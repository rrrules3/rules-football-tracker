//
//  RateLimiter.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation

actor RateLimiter {
    static let shared = RateLimiter();
    private let dailyLimit = 7500
    private let warningThreshold = 10

    private let countKey = "api_request_count"
    private let dateKey = "api_request_date"

    private init() {}

    // MARK: - Request Tracking

    var requestsUsed: Int {
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: countKey)
    }

    var requestsRemaining: Int {
        dailyLimit - requestsUsed
    }

    var isLowBudget: Bool {
        requestsRemaining <= warningThreshold
    }

    var isBudgetExhausted: Bool {
        requestsRemaining <= 0
    }

    func recordRequest() {
        resetIfNewDay()
        let current = UserDefaults.standard.integer(forKey: countKey)
        UserDefaults.standard.set(current + 1, forKey: countKey)

        if requestsRemaining <= warningThreshold {
            print("⚠️ API budget low: \(requestsRemaining) requests remaining today")
        }
    }

    func canMakeRequest(critical: Bool = false) -> Bool {
        resetIfNewDay()
        if isBudgetExhausted { return false }
        // Non-critical requests blocked when budget is low
        if !critical && isLowBudget { return false }
        return true
    }

    // MARK: - Day Reset

    private func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let storedDate = UserDefaults.standard.object(forKey: dateKey) as? Date ?? .distantPast
        let storedDay = Calendar.current.startOfDay(for: storedDate)

        if today > storedDay {
            UserDefaults.standard.set(0, forKey: countKey)
            UserDefaults.standard.set(today, forKey: dateKey)
            print("🔄 API budget reset for new day — \(dailyLimit) requests available")
        }
    }
}
