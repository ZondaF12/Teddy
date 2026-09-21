//
//  NotificationScheduler.swift
//  Teddy
//

import Foundation
import SwiftData
import UserNotifications

nonisolated enum NotificationScheduler {
    /// iOS drops pending requests above this limit.
    static let pendingRequestLimit = 64

    static let categoryIdentifier = "REMINDER"
    static let doneActionIdentifier = "DONE"
    static let reminderIDKey = "reminderID"

    static func registerCategories() {
        let done = UNNotificationAction(
            identifier: doneActionIdentifier,
            title: "Done",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [done],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

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
        await cancel(schedule)
        guard schedule.isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        for planned in schedule.plannedNotifications() {
            await addRequest(
                id: planned.identifier,
                title: schedule.title,
                body: schedule.body(slot: planned.slot),
                reminderID: schedule.id,
                trigger: planned.trigger,
                repeats: planned.repeats,
                center: center
            )
        }
    }

    static func cancel(_ schedule: ReminderSchedule) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(schedule.id.uuidString)-"
        let pending = await center.pendingNotificationRequests()
        var ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        ids.append(contentsOf: schedule.legacyIdentifiers)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func resyncAll(_ schedules: [ReminderSchedule]) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for schedule in schedules where schedule.isEnabled {
            await self.schedule(schedule)
        }
    }

    static func completeToday(reminderID: UUID, modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)
        let id = reminderID
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == id })
        guard let reminder = try? context.fetch(descriptor).first else { return }

        reminder.markCompletedToday()
        try? context.save()
        await schedule(reminder.schedule)
    }

    static func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }

    static func notifyNow(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func addRequest(
        id: String,
        title: String,
        body: String?,
        reminderID: UUID,
        trigger triggerComponents: DateComponents,
        repeats: Bool,
        center: UNUserNotificationCenter
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [reminderIDKey: reminderID.uuidString]
        if let body {
            content.body = body
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
