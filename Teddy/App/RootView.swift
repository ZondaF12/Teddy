//
//  RootView.swift
//  Teddy
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var reminders: [Reminder]

    var body: some View {
        NavigationStack {
            RemindersListView()
        }
        .task {
            NotificationScheduler.registerCategories()
            await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.resyncAll(reminders.map(\.schedule))
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
