//
//  HomeLeaveSettings.swift
//  Teddy
//

import Foundation
import SwiftData

enum LeaveRemindMode: String, CaseIterable, Identifiable {
    case always
    case withinHours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always: "Remind always"
        case .withinHours: "Within hours of a reminder"
        }
    }
}

@Model
final class HomeLeaveSettings {
    var latitude: Double?
    var longitude: Double?
    var radiusMeters: Double
    var isEnabled: Bool
    var remindModeRaw: String
    var withinHours: Int
    var notificationTitle: String
    var notificationBody: String
    var lastLeaveNotificationAt: Date?

    init(
        latitude: Double? = nil,
        longitude: Double? = nil,
        radiusMeters: Double = HomeLeaveSettings.defaultRadiusMeters,
        isEnabled: Bool = false,
        remindMode: LeaveRemindMode = .always,
        withinHours: Int = HomeLeaveSettings.defaultWithinHours,
        notificationTitle: String = HomeLeaveSettings.defaultTitle,
        notificationBody: String = HomeLeaveSettings.defaultBody,
        lastLeaveNotificationAt: Date? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.isEnabled = isEnabled
        self.remindModeRaw = remindMode.rawValue
        self.withinHours = withinHours
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
        self.lastLeaveNotificationAt = lastLeaveNotificationAt
    }

    var remindMode: LeaveRemindMode {
        get { LeaveRemindMode(rawValue: remindModeRaw) ?? .always }
        set { remindModeRaw = newValue.rawValue }
    }

    var hasHomeLocation: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: (latitude: Double, longitude: Double)? {
        guard let latitude, let longitude else { return nil }
        return (latitude, longitude)
    }
}

extension HomeLeaveSettings {
    static let defaultRadiusMeters: Double = 150
    static let defaultWithinHours = 2
    static let withinHoursChoices = Array(1...12)
    static let defaultTitle = "Leaving home"
    static let defaultBody = "Remember your car keys"
    static let leaveCooldown: TimeInterval = 30 * 60
    static let homeRegionID = "teddy.home"

    static func ensureExists(in context: ModelContext) -> HomeLeaveSettings {
        let descriptor = FetchDescriptor<HomeLeaveSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = HomeLeaveSettings()
        context.insert(created)
        return created
    }

    static func shouldNotifyOnLeave(
        isEnabled: Bool,
        hasHomeLocation: Bool,
        remindMode: LeaveRemindMode,
        withinHours: Int,
        lastLeaveNotificationAt: Date?,
        reminders: [(isEnabled: Bool, hour: Int, minute: Int, repeatCount: Int, intervalMinutes: Int, lastCompletedDay: Date?)],
        now: Date = .now,
        calendar: Calendar = .current,
        cooldown: TimeInterval = HomeLeaveSettings.leaveCooldown
    ) -> Bool {
        guard isEnabled, hasHomeLocation else { return false }

        if let lastLeaveNotificationAt,
           now.timeIntervalSince(lastLeaveNotificationAt) < cooldown {
            return false
        }

        switch remindMode {
        case .always:
            return true
        case .withinHours:
            return hasReminderFiring(
                withinHours: withinHours,
                reminders: reminders,
                from: now,
                calendar: calendar
            )
        }
    }

    static func hasReminderFiring(
        withinHours hours: Int,
        reminders: [(isEnabled: Bool, hour: Int, minute: Int, repeatCount: Int, intervalMinutes: Int, lastCompletedDay: Date?)],
        from now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard hours > 0,
              let windowEnd = calendar.date(byAdding: .hour, value: hours, to: now)
        else {
            return false
        }

        let lookAheadDays = max(1, Int(ceil(Double(hours) / 24.0)) + 1)
        for reminder in reminders where reminder.isEnabled {
            let fires = Reminder.upcomingFireDates(
                hour: reminder.hour,
                minute: reminder.minute,
                repeatCount: reminder.repeatCount,
                intervalMinutes: reminder.intervalMinutes,
                lastCompletedDay: reminder.lastCompletedDay,
                from: now,
                calendar: calendar,
                lookAheadDays: lookAheadDays
            )
            if fires.contains(where: { $0.date <= windowEnd }) {
                return true
            }
        }
        return false
    }
}
