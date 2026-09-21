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
                            .onTapGesture { editingReminder = reminder }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if reminder.isEnabled && !reminder.isCompletedToday {
                                    Button("Done") {
                                        markDone(reminder)
                                    }
                                    .tint(.green)
                                }
                            }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .listRowSpacing(10)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.screenGradient().ignoresSafeArea())
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
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

    private func markDone(_ reminder: Reminder) {
        reminder.markCompletedToday()
        let schedule = reminder.schedule
        Task { await NotificationScheduler.schedule(schedule) }
    }

    private func delete(at offsets: IndexSet) {
        let schedules = offsets.map { reminders[$0].schedule }
        for index in offsets {
            modelContext.delete(reminders[index])
        }
        Task {
            for schedule in schedules {
                await NotificationScheduler.cancel(schedule)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RemindersListView()
    }
    .modelContainer(for: [Reminder.self, HomeLeaveSettings.self], inMemory: true)
}
