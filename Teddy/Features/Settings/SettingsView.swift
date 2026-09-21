//
//  SettingsView.swift
//  Teddy
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [HomeLeaveSettings]

    @State private var isLocating = false
    @State private var locationError: String?
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if let settings = settingsList.first {
                settingsForm(settings)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.screenGradient().ignoresSafeArea())
        .onAppear {
            _ = HomeLeaveSettings.ensureExists(in: modelContext)
            if let settings = settingsList.first {
                syncMapCamera(settings)
            }
            LocationMonitor.shared.refreshMonitoring()
        }
        .alert("Location Unavailable", isPresented: Binding(
            get: { locationError != nil },
            set: { if !$0 { locationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(locationError ?? "")
        }
    }

    @ViewBuilder
    private func settingsForm(_ settings: HomeLeaveSettings) -> some View {
        Form {
            Section {
                Toggle("Leave-home alerts", isOn: bind(settings, \.isEnabled))
            } footer: {
                Text("Notify you with a custom message when you leave home.")
            }

            Section("Message") {
                TextField("Title", text: bind(settings, \.notificationTitle))
                TextField("Message", text: bind(settings, \.notificationBody), axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Picker("Mode", selection: remindModeBinding(settings)) {
                    ForEach(LeaveRemindMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if settings.remindMode == .withinHours {
                    Picker("Within", selection: bind(settings, \.withinHours)) {
                        ForEach(HomeLeaveSettings.withinHoursChoices, id: \.self) { hours in
                            Text(hours == 1 ? "1 hour" : "\(hours) hours").tag(hours)
                        }
                    }
                }
            } header: {
                Text("When")
            } footer: {
                Text(whenFooter(settings))
            }

            Section {
                if let coordinate = settings.coordinate {
                    Map(position: $mapPosition) {
                        Annotation("Home", coordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude)) {
                            Image(systemName: "house.fill")
                                .foregroundStyle(Theme.accent)
                        }
                        MapCircle(
                            center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
                            radius: settings.radiusMeters
                        )
                        .foregroundStyle(Theme.accent.opacity(0.2))
                        .stroke(Theme.accent, lineWidth: 1)
                    }
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                }

                Button {
                    Task { await useCurrentLocation(settings) }
                } label: {
                    if isLocating {
                        ProgressView()
                    } else {
                        Label(
                            settings.hasHomeLocation ? "Update to Current Location" : "Use Current Location",
                            systemImage: "location.fill"
                        )
                    }
                }
                .disabled(isLocating)

                if settings.hasHomeLocation {
                    Button("Clear Home", role: .destructive) {
                        settings.latitude = nil
                        settings.longitude = nil
                        LocationMonitor.shared.refreshMonitoring()
                    }
                }
            } header: {
                Text("Home")
            } footer: {
                Text(homeFooter(settings))
            }
        }
        .scrollContentBackground(.hidden)
        .onChange(of: settings.isEnabled) {
            if settings.isEnabled {
                LocationMonitor.shared.requestPermissions()
            }
            LocationMonitor.shared.refreshMonitoring()
        }
        .onChange(of: settings.latitude) {
            syncMapCamera(settings)
        }
        .onChange(of: settings.longitude) {
            syncMapCamera(settings)
        }
    }

    private func whenFooter(_ settings: HomeLeaveSettings) -> String {
        switch settings.remindMode {
        case .always:
            return "Sends your message every time you leave home."
        case .withinHours:
            return "Sends your message only if a reminder is due within the next \(settings.withinHours) hours."
        }
    }

    private func homeFooter(_ settings: HomeLeaveSettings) -> String {
        switch LocationMonitor.shared.authorizationStatus {
        case .denied, .restricted:
            return "Location access is off. Enable it in iOS Settings to use leave-home alerts."
        case .authorizedWhenInUse:
            return "For reliable alerts while the app is closed, allow Location to Always."
        default:
            return "Teddy uses a \(Int(settings.radiusMeters))m geofence around home."
        }
    }

    private func remindModeBinding(_ settings: HomeLeaveSettings) -> Binding<LeaveRemindMode> {
        Binding(
            get: { settings.remindMode },
            set: { settings.remindMode = $0 }
        )
    }

    private func bind<T>(
        _ settings: HomeLeaveSettings,
        _ keyPath: ReferenceWritableKeyPath<HomeLeaveSettings, T>
    ) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }

    private func useCurrentLocation(_ settings: HomeLeaveSettings) async {
        isLocating = true
        defer { isLocating = false }

        LocationMonitor.shared.requestPermissions()

        do {
            let location = try await LocationMonitor.shared.currentLocation()
            settings.latitude = location.coordinate.latitude
            settings.longitude = location.coordinate.longitude
            syncMapCamera(settings)
            LocationMonitor.shared.refreshMonitoring()
        } catch {
            locationError = "Couldn't get your current location. Check that Location is allowed for Teddy."
        }
    }

    private func syncMapCamera(_ settings: HomeLeaveSettings) {
        guard let coordinate = settings.coordinate else { return }
        let region = MKCoordinateRegion(
            center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
            latitudinalMeters: settings.radiusMeters * 4,
            longitudinalMeters: settings.radiusMeters * 4
        )
        mapPosition = .region(region)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Reminder.self, HomeLeaveSettings.self], inMemory: true)
}
