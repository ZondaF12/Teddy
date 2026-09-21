//
//  LocationMonitor.swift
//  Teddy
//

import CoreLocation
import Foundation
import SwiftData

@MainActor
final class LocationMonitor: NSObject, CLLocationManagerDelegate {
    static let shared = LocationMonitor()

    private let manager = CLLocationManager()
    private var modelContainer: ModelContainer?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var isAuthorizedForMonitoring: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    func requestPermissions() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func refreshMonitoring() {
        guard let modelContainer else {
            stopMonitoring()
            return
        }

        let context = ModelContext(modelContainer)
        let settings = HomeLeaveSettings.ensureExists(in: context)

        guard settings.isEnabled, let coordinate = settings.coordinate else {
            stopMonitoring()
            return
        }

        guard isAuthorizedForMonitoring else {
            stopMonitoring()
            return
        }

        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
            radius: settings.radiusMeters,
            identifier: HomeLeaveSettings.homeRegionID
        )
        region.notifyOnEntry = false
        region.notifyOnExit = true

        for monitored in manager.monitoredRegions {
            manager.stopMonitoring(for: monitored)
        }
        manager.startMonitoring(for: region)
        manager.requestState(for: region)

        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    func stopMonitoring() {
        for monitored in manager.monitoredRegions {
            manager.stopMonitoring(for: monitored)
        }
    }

    func currentLocation() async throws -> CLLocation {
        if let location = manager.location, location.timestamp.timeIntervalSinceNow > -60 {
            return location
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation?.resume(throwing: CancellationError())
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse:
                manager.requestAlwaysAuthorization()
                refreshMonitoring()
            case .authorizedAlways:
                refreshMonitoring()
            case .denied, .restricted:
                stopMonitoring()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == HomeLeaveSettings.homeRegionID else { return }
        Task { @MainActor in
            await handleExit()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }

    private func handleExit() async {
        guard let modelContainer else { return }

        let context = ModelContext(modelContainer)
        let settings = HomeLeaveSettings.ensureExists(in: context)
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []

        let snapshot = reminders.map {
            (
                isEnabled: $0.isEnabled,
                hour: $0.hour,
                minute: $0.minute,
                repeatCount: $0.repeatCount,
                intervalMinutes: $0.intervalMinutes,
                lastCompletedDay: $0.lastCompletedDay
            )
        }

        let shouldNotify = HomeLeaveSettings.shouldNotifyOnLeave(
            isEnabled: settings.isEnabled,
            hasHomeLocation: settings.hasHomeLocation,
            remindMode: settings.remindMode,
            withinHours: settings.withinHours,
            lastLeaveNotificationAt: settings.lastLeaveNotificationAt,
            reminders: snapshot
        )

        guard shouldNotify else { return }

        let title = settings.notificationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = settings.notificationBody.trimmingCharacters(in: .whitespacesAndNewlines)
        await NotificationScheduler.notifyNow(
            id: "leave-home-\(Int(Date().timeIntervalSince1970))",
            title: title.isEmpty ? HomeLeaveSettings.defaultTitle : title,
            body: body.isEmpty ? HomeLeaveSettings.defaultBody : body
        )

        settings.lastLeaveNotificationAt = .now
        try? context.save()
    }
}
