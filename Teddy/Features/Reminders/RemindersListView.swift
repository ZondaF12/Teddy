//
//  RemindersListView.swift
//  Teddy
//

import SwiftUI
import SwiftData

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.createdAt) private var reminders: [Reminder]

    @State private var isAddingReminder = false
    @State private var editingReminder: Reminder?

    var body: some View {
        Group {
            if reminders.isEmpty {
                ContentUnavailableView(
                    "No Reminders Yet",
                    systemImage: "bell.badge",
                    description: Text("Zara go tap + to add a reminder otherwise this was pointless.")
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
        .navigationTitle("Reminders")
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

    // MARK: - Private

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

#Preview {
    NavigationStack {
        RemindersListView()
    }
    .modelContainer(for: Reminder.self, inMemory: true)
}
