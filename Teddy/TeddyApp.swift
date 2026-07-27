//
//  TeddyApp.swift
//  Teddy
//
//  Created by Ruaridh Bell on 27/07/2026.
//

import SwiftUI
import SwiftData

@main
struct TeddyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Reminder.self)
    }
}
