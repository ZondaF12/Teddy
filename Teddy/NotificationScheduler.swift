//
//  NotificationScheduler.swift
//  Teddy
//
//  Created by Ruaridh Bell on 27/07/2026.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    /// iOS keeps at most 64 pending requests per app and silently drops the rest.
    /// Each repeating burst slot costs one, so ~64 enabled slots is the ceiling.
    static let pendingRequestLimit = 64

    private static var center: UNUserNotificationCenter { .current() }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(_ schedule: ReminderSchedule) async {
        cancel(schedule)
        guard schedule.isEnabled else { return }

        let total = schedule.fireTimes.count
        for (slot, components) in schedule.fireTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = schedule.title
            content.sound = .default
            if total > 1 {
                content.body = "Reminder \(slot + 1) of \(total)"
            }

            let request = UNNotificationRequest(
                identifier: schedule.identifier(slot: slot),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }
    }

    static func cancel(_ schedule: ReminderSchedule) {
        center.removePendingNotificationRequests(withIdentifiers: schedule.allIdentifiers)
    }

    /// Clears everything and rebuilds from the stored reminders, healing any drift
    /// from edits made while the app was not running.
    static func resyncAll(_ schedules: [ReminderSchedule]) async {
        center.removeAllPendingNotificationRequests()
        for schedule in schedules where schedule.isEnabled {
            await self.schedule(schedule)
        }
    }

    static func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }
}
