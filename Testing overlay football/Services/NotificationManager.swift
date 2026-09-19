//
//  NotificationManager.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // Action identifiers
    nonisolated static let watchLiveAction = "WATCH_LIVE"
    nonisolated static let dismissAction = "DISMISS"
    nonisolated static let matchCategory = "MATCH_ALERT"

    // Callback when user taps "Watch Live"
    var onWatchLive: ((Int) -> Void)?  // fixtureID

    // Track which fixtures we've already notified for
    private var notifiedFixtures: Set<Int> = []

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("🔔 Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }

        // Register action buttons
        let watchAction = UNNotificationAction(
            identifier: Self.watchLiveAction,
            title: "Watch Live",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: Self.dismissAction,
            title: "Dismiss",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.matchCategory,
            actions: [watchAction, dismissAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Schedule Pre-Match Alert

    func schedulePreMatchAlert(for match: LiveMatch) {
        // Don't notify twice for the same fixture
        guard !notifiedFixtures.contains(match.id) else { return }

        // Only notify for matches that haven't started yet
        guard match.status == .notStarted else { return }

        // Check if kickoff is within 15 minutes
        let minutesUntilKickoff = match.kickoffDate.timeIntervalSinceNow / 60
        guard minutesUntilKickoff > 0 && minutesUntilKickoff <= 15 else { return }

        notifiedFixtures.insert(match.id)

        let content = UNMutableNotificationContent()
        content.title = "\(match.homeTeam.name) vs \(match.awayTeam.name)"
        content.body = "Kicks off in \(Int(minutesUntilKickoff)) minutes. Watch live?"
        content.sound = .default
        content.categoryIdentifier = Self.matchCategory
        content.userInfo = ["fixtureID": match.id]

        // Fire immediately (match is already within 15 min window)
        let request = UNNotificationRequest(
            identifier: "match-\(match.id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("🔔 Notification scheduled: \(match.homeTeam.name) vs \(match.awayTeam.name)")
            }
        }
    }

    // MARK: - Goal Notification

    func sendGoalNotification(match: LiveMatch, scoringTeamName: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚽  Goal — \(scoringTeamName)"
        content.body  = "\(match.homeTeam.name)  \(match.homeScore) – \(match.awayScore)  \(match.awayTeam.name)  ·  \(match.clock)"
        content.sound = .default
        content.categoryIdentifier = Self.matchCategory
        content.userInfo = ["fixtureID": match.id]

        // Unique ID per scoreline so two quick goals don't overwrite each other
        let request = UNNotificationRequest(
            identifier: "goal-\(match.id)-\(match.homeScore)-\(match.awayScore)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ Goal notification error: \(error.localizedDescription)") }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle action button taps
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let fixtureID = userInfo["fixtureID"] as? Int

        if response.actionIdentifier == Self.watchLiveAction ||
           response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let fixtureID = fixtureID {
                Task { @MainActor in
                    self.onWatchLive?(fixtureID)
                }
            }
        }

        completionHandler()
    }
}
