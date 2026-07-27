//
//  Reminder.swift
//  Teddy
//
//  A named daily reminder plus the burst of notification slots it fires.
//

import Foundation
import SwiftData

@Model
final class Reminder {
    /// Kept stable across edits so scheduled notification identifiers stay valid.
    var id: UUID
    var name: String
    /// Optional notification body. Defaulted so existing stores migrate lightly.
    var details: String = ""
    var hour: Int
    var minute: Int
    var repeatCount: Int
    var intervalMinutes: Int
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        hour: Int,
        minute: Int,
        repeatCount: Int = 1,
        intervalMinutes: Int = Reminder.defaultIntervalMinutes,
        isEnabled: Bool = true,
        createdAt: Date = .now
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
    }
}

extension Reminder {
    static let maxRepeatCount = 10
    static let intervalChoices = [5, 10, 15, 20, 30, 60]
    static let defaultIntervalMinutes = 20

    /// Burst slots as daily-matching components, wrapping past midnight.
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

    var fireTimes: [DateComponents] {
        Self.fireTimes(hour: hour, minute: minute, repeatCount: repeatCount, intervalMinutes: intervalMinutes)
    }

    var burstLabel: String {
        Self.burstLabel(repeatCount: repeatCount, intervalMinutes: intervalMinutes)
    }

    var timeLabel: String {
        DateComponents(hour: hour, minute: minute).timeLabel
    }

    /// Sendable copy of everything the scheduler needs, so models never cross a concurrency boundary.
    var schedule: ReminderSchedule {
        ReminderSchedule(id: id, title: name, details: details, isEnabled: isEnabled, fireTimes: fireTimes)
    }
}

/// Immutable view of a reminder's notification schedule.
struct ReminderSchedule: Sendable {
    let id: UUID
    let title: String
    let details: String
    let isEnabled: Bool
    let fireTimes: [DateComponents]

    func identifier(slot: Int) -> String {
        "\(id)-\(slot)"
    }

    /// A description replaces the burst progress text; without one, multi-slot
    /// bursts fall back to "Reminder 2 of 3" and single shots have no body.
    func body(slot: Int) -> String? {
        guard details.isEmpty else { return details }
        guard fireTimes.count > 1 else { return nil }
        return "Reminder \(slot + 1) of \(fireTimes.count)"
    }

    /// Covers every slot a reminder could ever occupy, so shrinking a burst
    /// cannot leave higher-numbered requests scheduled.
    var allIdentifiers: [String] {
        (0..<Reminder.maxRepeatCount).map(identifier(slot:))
    }
}

extension DateComponents {
    /// Formats an hour/minute pair in the user's locale, e.g. "1:00 PM".
    var timeLabel: String {
        let reference = DateComponents(year: 2000, month: 1, day: 1, hour: hour ?? 0, minute: minute ?? 0)
        guard let date = Calendar.current.date(from: reference) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
