//
//  ContentView.swift
//  Teddy
//
//  Created by Ruaridh Bell on 27/07/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.createdAt) private var reminders: [Reminder]

    @State private var isAddingReminder = false
    @State private var editingReminder: Reminder?

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders Yet",
                        systemImage: "bell.badge",
                        description: Text("Tap + to add a reminder that nudges you on repeat.")
                    )
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            ReminderRow(reminder: reminder)
                                .contentShape(.rect)
                                .onTapGesture { editingReminder = reminder }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Teddy")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Reminder", systemImage: "plus") { isAddingReminder = true }
                }
            }
            .sheet(isPresented: $isAddingReminder) {
                ReminderEditView(reminder: nil)
            }
            .sheet(item: $editingReminder) { reminder in
                ReminderEditView(reminder: reminder)
            }
        }
        .task {
            await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.resyncAll(reminders.map(\.schedule))
        }
    }

    private func delete(at offsets: IndexSet) {
        // Snapshot before deleting; the models are unusable afterwards.
        let schedules = offsets.map { reminders[$0].schedule }
        for schedule in schedules {
            NotificationScheduler.cancel(schedule)
        }
        for index in offsets {
            modelContext.delete(reminders[index])
        }
    }
}

private struct ReminderRow: View {
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
    ContentView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
