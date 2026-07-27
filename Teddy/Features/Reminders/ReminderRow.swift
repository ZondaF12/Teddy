//
//  ReminderRow.swift
//  Teddy
//

import SwiftUI
import SwiftData

struct ReminderRow: View {
    @Bindable var reminder: Reminder

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.timeLabel)
                    .font(.title2)
                    .fontWeight(.medium)
                Text(reminder.name)
                Text(reminder.burstLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(reminder.isEnabled ? 1 : 0.4)

            Spacer()

            Toggle(reminder.name, isOn: $reminder.isEnabled)
                .labelsHidden()
        }
        .onChange(of: reminder.isEnabled) {
            let schedule = reminder.schedule
            Task { await NotificationScheduler.schedule(schedule) }
        }
    }
}

#Preview {
    List {
        ReminderRow(reminder: Reminder(name: "Drink water", hour: 13, minute: 0, repeatCount: 3))
        ReminderRow(reminder: Reminder(name: "Stretch", hour: 9, minute: 30, isEnabled: false))
    }
    .modelContainer(for: Reminder.self, inMemory: true)
}
