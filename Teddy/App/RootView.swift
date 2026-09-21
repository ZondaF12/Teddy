//
//  RootView.swift
//  Teddy
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            let schedules = reminders.map(\.schedule)
            Task { await NotificationScheduler.resyncAll(schedules) }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Reminder.self, HomeLeaveSettings.self], inMemory: true)
}
