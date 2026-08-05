//
//  Reminder.swift
//  Teddy
//

import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var name: String
    var details: String = ""
    var hour: Int
    var minute: Int
    var repeatCount: Int
    var intervalMinutes: Int
    var isEnabled: Bool
    var createdAt: Date
    /// Start of day last marked Done; skips today's remaining burst.
    var lastCompletedDay: Date?

    init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        hour: Int,
        minute: Int,
        repeatCount: Int = 1,
        intervalMinutes: Int = Reminder.defaultIntervalMinutes,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        lastCompletedDay: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.hour = hour
        self.minute = minute
        self.repeatCount = repeatCount
        self.intervalMinutes = intervalMinutes
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastCompletedDay = lastCompletedDay
    }

    func markCompletedToday(calendar: Calendar = .current, now: Date = .now) {
        lastCompletedDay = calendar.startOfDay(for: now)
    }

    var isCompletedToday: Bool {
        Self.isCompleted(on: lastCompletedDay, calendar: .current, now: .now)
    }
}

extension Reminder {
    static let maxRepeatCount = 10
    static let intervalChoices = [5, 10, 15, 20, 30, 60]
    static let defaultIntervalMinutes = 20
    static let scheduleLookAheadDays = 3

    static func fireTimes(hour: Int, minute: Int, repeatCount: Int, intervalMinutes: Int) -> [DateComponents] {
        let minutesPerDay = 24 * 60
        return (0..<max(1, repeatCount)).map { slot in
            let total = (hour * 60 + minute + slot * intervalMinutes) % minutesPerDay
            return DateComponents(hour: total / 60, minute: total % 60)
        }
    }

    static func burstLabel(repeatCount: Int, intervalMinutes: Int) -> String {
        repeatCount > 1 ? "\(repeatCount)× every \(intervalMinutes) min" : "Once"
    }

    static func isCompleted(on lastCompletedDay: Date?, calendar: Calendar, now: Date) -> Bool {
        guard let lastCompletedDay else { return false }
        return calendar.isDate(lastCompletedDay, inSameDayAs: calendar.startOfDay(for: now))
    }

    static func upcomingFireDates(
        hour: Int,
        minute: Int,
        repeatCount: Int,
        intervalMinutes: Int,
        lastCompletedDay: Date?,
        from now: Date = .now,
        calendar: Calendar = .current,
        lookAheadDays: Int = Reminder.scheduleLookAheadDays
    ) -> [(slot: Int, date: Date)] {
        let startOfToday = calendar.startOfDay(for: now)
        let skipToday = isCompleted(on: lastCompletedDay, calendar: calendar, now: now)
        let slotComponents = fireTimes(
            hour: hour,
            minute: minute,
            repeatCount: repeatCount,
            intervalMinutes: intervalMinutes
        )

        var result: [(slot: Int, date: Date)] = []
        for dayOffset in 0..<max(1, lookAheadDays) {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            if dayOffset == 0 && skipToday { continue }

            for (slot, components) in slotComponents.enumerated() {
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
                dateComponents.hour = components.hour
                dateComponents.minute = components.minute
                dateComponents.second = 0
                guard let fireDate = calendar.date(from: dateComponents), fireDate > now else { continue }
                result.append((slot: slot, date: fireDate))
            }
        }
        return result
    }

    var fireTimes: [DateComponents] {
        Self.fireTimes(hour: hour, minute: minute, repeatCount: repeatCount, intervalMinutes: intervalMinutes)
    }

    var burstLabel: String {
        Self.burstLabel(repeatCount: repeatCount, intervalMinutes: intervalMinutes)
    }

    var timeLabel: String {
        DateComponents(hour: hour, minute: minute).timeLabel
    }

    var schedule: ReminderSchedule {
        ReminderSchedule(
            id: id,
            title: name,
            details: details,
            isEnabled: isEnabled,
            hour: hour,
            minute: minute,
            repeatCount: repeatCount,
            intervalMinutes: intervalMinutes,
            lastCompletedDay: lastCompletedDay
        )
    }
}

struct ReminderSchedule: Sendable {
    let id: UUID
    let title: String
    let details: String
    let isEnabled: Bool
    let hour: Int
    let minute: Int
    let repeatCount: Int
    let intervalMinutes: Int
    let lastCompletedDay: Date?

    var fireTimes: [DateComponents] {
        Reminder.fireTimes(
            hour: hour,
            minute: minute,
            repeatCount: repeatCount,
            intervalMinutes: intervalMinutes
        )
    }

    func identifier(slot: Int, on day: Date, calendar: Calendar = .current) -> String {
        "\(id.uuidString)-\(slot)-\(Self.dayKey(for: day, calendar: calendar))"
    }

    /// Ids from the old repeating-slot scheduler.
    var legacyIdentifiers: [String] {
        (0..<Reminder.maxRepeatCount).map { "\(id.uuidString)-\($0)" }
    }

    func body(slot: Int) -> String? {
        guard details.isEmpty else { return details }
        guard fireTimes.count > 1 else { return nil }
        return "Reminder \(slot + 1) of \(fireTimes.count)"
    }

    func upcomingFireDates(
        from now: Date = .now,
        calendar: Calendar = .current
    ) -> [(slot: Int, date: Date)] {
        Reminder.upcomingFireDates(
            hour: hour,
            minute: minute,
            repeatCount: repeatCount,
            intervalMinutes: intervalMinutes,
            lastCompletedDay: lastCompletedDay,
            from: now,
            calendar: calendar
        )
    }

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let dayValue = components.day ?? 0
        return String(format: "%04d%02d%02d", year, month, dayValue)
    }
}

extension DateComponents {
    var timeLabel: String {
        let reference = DateComponents(year: 2000, month: 1, day: 1, hour: hour ?? 0, minute: minute ?? 0)
        guard let date = Calendar.current.date(from: reference) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
