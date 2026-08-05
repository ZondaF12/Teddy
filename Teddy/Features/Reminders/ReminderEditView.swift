//
//  ReminderEditView.swift
//  Teddy
//

import SwiftUI
import SwiftData

struct ReminderEditView: View {
    private let reminder: Reminder?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Staged locally so Cancel can discard (SwiftData autosaves).
    @State private var name: String
    @State private var details: String
    @State private var time: Date
    @State private var repeatCount: Int
    @State private var intervalMinutes: Int

    init(reminder: Reminder?) {
        self.reminder = reminder
        _name = State(initialValue: reminder?.name ?? "")
        _details = State(initialValue: reminder?.details ?? "")
        _repeatCount = State(initialValue: reminder?.repeatCount ?? 1)
        _intervalMinutes = State(initialValue: reminder?.intervalMinutes ?? Reminder.defaultIntervalMinutes)

        let hour = reminder?.hour ?? 9
        let minute = reminder?.minute ?? 0
        let start = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now)
        _time = State(initialValue: start ?? .now)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewTimes: [DateComponents] {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Reminder.fireTimes(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            repeatCount: repeatCount,
            intervalMinutes: intervalMinutes
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(1...3)
                } footer: {
                    Text(trimmedDetails.isEmpty && repeatCount > 1
                         ? "Without a description, each notification shows its place in the burst."
                         : "Shown as the notification message.")
                }

                Section("Time") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section {
                    Picker("Remind me", selection: $repeatCount) {
                        ForEach(1...Reminder.maxRepeatCount, id: \.self) { count in
                            Text(count == 1 ? "Once" : "\(count) times").tag(count)
                        }
                    }

                    if repeatCount > 1 {
                        Picker("Every", selection: $intervalMinutes) {
                            ForEach(Reminder.intervalChoices, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                    }
                }

                if repeatCount > 1 {
                    Section("Fires at") {
                        Text(previewTimes.map(\.timeLabel).formatted(.list(type: .and)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let target = reminder ?? Reminder(name: trimmedName, hour: 0, minute: 0)

        target.name = trimmedName
        target.details = trimmedDetails
        target.hour = components.hour ?? 0
        target.minute = components.minute ?? 0
        target.repeatCount = repeatCount
        target.intervalMinutes = intervalMinutes

        if reminder == nil {
            modelContext.insert(target)
        }

        let schedule = target.schedule
        Task { await NotificationScheduler.schedule(schedule) }
        dismiss()
    }
}

#Preview {
    ReminderEditView(reminder: nil)
        .modelContainer(for: Reminder.self, inMemory: true)
}
