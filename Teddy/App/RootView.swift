//
//  RootView.swift
//  Teddy
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var reminders: [Reminder]

    var body: some View {
        NavigationStack {
            RemindersListView()
        }
        .task {
            _ = HomeLeaveSettings.ensureExists(in: modelContext)
            NotificationScheduler.registerCategories()
            await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.resyncAll(reminders.map(\.schedule))
            LocationMonitor.shared.refreshMonitoring()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Reminder.self, HomeLeaveSettings.self], inMemory: true)
}
