//
//  TeddyTests.swift
//  TeddyTests
//
//  Created by Ruaridh Bell on 27/07/2026.
//

import Foundation
import Testing
@testable import Teddy

struct TeddyTests {

    @Test func upcomingFireDatesIncludesRemainingBurstSlots() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = date(calendar, 2026, 8, 5, 13, 5)
        let fires = Reminder.upcomingFireDates(
            hour: 13,
            minute: 0,
            repeatCount: 3,
            intervalMinutes: 20,
            lastCompletedDay: nil,
            from: now,
            calendar: calendar,
            lookAheadDays: 1
        )

        #expect(fires.map(\.slot) == [1, 2])
        #expect(fires.map(\.date) == [
            date(calendar, 2026, 8, 5, 13, 20),
            date(calendar, 2026, 8, 5, 13, 40),
        ])
    }

    @Test func upcomingFireDatesSkipsTodayWhenCompleted() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = date(calendar, 2026, 8, 5, 13, 5)
        let completed = calendar.startOfDay(for: now)
        let fires = Reminder.upcomingFireDates(
            hour: 13,
            minute: 0,
            repeatCount: 3,
            intervalMinutes: 20,
            lastCompletedDay: completed,
            from: now,
            calendar: calendar,
            lookAheadDays: 2
        )

        #expect(fires.map(\.slot) == [0, 1, 2])
        #expect(fires.map(\.date) == [
            date(calendar, 2026, 8, 6, 13, 0),
            date(calendar, 2026, 8, 6, 13, 20),
            date(calendar, 2026, 8, 6, 13, 40),
        ])
    }

    @Test func markCompletedTodaySetsStartOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(calendar, 2026, 8, 5, 13, 5)

        let reminder = Reminder(name: "Water", hour: 13, minute: 0, repeatCount: 3)
        reminder.markCompletedToday(calendar: calendar, now: now)

        #expect(reminder.lastCompletedDay == calendar.startOfDay(for: now))
        #expect(Reminder.isCompleted(on: reminder.lastCompletedDay, calendar: calendar, now: now))
    }

    private func date(
        _ calendar: Calendar,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }
}
