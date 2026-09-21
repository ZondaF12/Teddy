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

    @Test func leaveNotifyAlwaysWhenEnabled() {
        let now = date(Calendar(identifier: .gregorian), 2026, 8, 5, 13, 30)
        let should = HomeLeaveSettings.shouldNotifyOnLeave(
            isEnabled: true,
            hasHomeLocation: true,
            remindMode: .always,
            withinHours: 2,
            lastLeaveNotificationAt: nil,
            reminders: [],
            now: now,
            cooldown: 0
        )
        #expect(should)
    }

    @Test func leaveNotifyWithinHoursOnlyWhenReminderUpcoming() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(calendar, 2026, 8, 5, 13, 30)
        let reminder = (
            isEnabled: true,
            hour: 15,
            minute: 0,
            repeatCount: 1,
            intervalMinutes: 20,
            lastCompletedDay: Date?.none
        )

        let inWindow = HomeLeaveSettings.shouldNotifyOnLeave(
            isEnabled: true,
            hasHomeLocation: true,
            remindMode: .withinHours,
            withinHours: 2,
            lastLeaveNotificationAt: nil,
            reminders: [reminder],
            now: now,
            calendar: calendar,
            cooldown: 0
        )
        #expect(inWindow)

        let outOfWindow = HomeLeaveSettings.shouldNotifyOnLeave(
            isEnabled: true,
            hasHomeLocation: true,
            remindMode: .withinHours,
            withinHours: 2,
            lastLeaveNotificationAt: nil,
            reminders: [reminder],
            now: date(calendar, 2026, 8, 5, 12, 0),
            calendar: calendar,
            cooldown: 0
        )
        #expect(!outOfWindow)
    }

    @Test func leaveNotifyRespectsCooldown() {
        let now = date(Calendar(identifier: .gregorian), 2026, 8, 5, 13, 30)
        let recent = now.addingTimeInterval(-60)
        let should = HomeLeaveSettings.shouldNotifyOnLeave(
            isEnabled: true,
            hasHomeLocation: true,
            remindMode: .always,
            withinHours: 2,
            lastLeaveNotificationAt: recent,
            reminders: [],
            now: now,
            cooldown: 30 * 60
        )
        #expect(!should)
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
