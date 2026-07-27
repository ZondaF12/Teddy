//
//  RootView.swift
//  Teddy
//

import SwiftUI
import SwiftData

struct RootView: View {
    /// Resyncing needs the stored reminders, which a Scene cannot query — so the
    /// launch work lives here rather than in TeddyApp.
    @Query private var reminders: [Reminder]

    var body: some View {
        NavigationStack {
            RemindersListView()
        }
        .task {
            await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.resyncAll(reminders.map(\.schedule))
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
