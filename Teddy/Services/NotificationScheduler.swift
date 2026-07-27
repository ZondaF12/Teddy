//
//  NotificationScheduler.swift
//  Teddy
//
//  Local UserNotifications for reminder bursts — one repeating daily
//  calendar trigger per slot.
//

import Foundation
import UserNotifications

nonisolated enum NotificationScheduler {
    /// iOS keeps at most 64 pending requests per app and silently drops the rest.
    /// Each repeating burst slot costs one, so ~64 enabled slots is the ceiling.
    static let pendingRequestLimit = 64

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func authorizationDenied() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .denied
    }

    static func schedule(_ schedule: ReminderSchedule) async {
        cancel(schedule)
        guard schedule.isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        for (slot, components) in schedule.fireTimes.enumerated() {
            await addRequest(
                id: schedule.identifier(slot: slot),
                title: schedule.title,
                body: schedule.body(slot: slot),
                components: components,
                center: center
            )
        }
    }

    static func cancel(_ schedule: ReminderSchedule) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: schedule.allIdentifiers)
    }

    /// Clears everything and rebuilds from the stored reminders, healing any drift
    /// from edits made while the app was not running.
    static func resyncAll(_ schedules: [ReminderSchedule]) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for schedule in schedules where schedule.isEnabled {
            await self.schedule(schedule)
        }
    }

    static func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }

    // MARK: - Private

    private static func addRequest(
        id: String,
        title: String,
        body: String?,
        components: DateComponents,
        center: UNUserNotificationCenter
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        if let body {
            content.body = body
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
