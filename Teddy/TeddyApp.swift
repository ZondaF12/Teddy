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
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(appDelegate.modelContainer)
    }
}
