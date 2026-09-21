# Leave-home alerts

## What it does

A new Settings screen (gear icon, top-left of the Reminders list) lets you save
your home location and write a custom notification — "Leaving home / Remember
your car keys" by default. When you walk out of a ~150 m circle around home,
Teddy sends that notification.

You choose when it fires:

- **Remind always** — every time you leave.
- **Within hours of a reminder** — only if one of your enabled reminders is due
  within the next 1–12 hours (and hasn't been marked Done today).

A 30-minute cooldown stops GPS jitter at the edge of the circle from sending the
same alert several times in a row.

## How it works

1. `AppDelegate` creates the SwiftData container with both `Reminder` and
   `HomeLeaveSettings`, hands it to `LocationMonitor.shared`, and calls
   `refreshMonitoring()` on launch.
2. In Settings, "Use Current Location" asks for location permission, grabs a
   one-off fix, and stores the latitude/longitude on the single
   `HomeLeaveSettings` row.
3. `refreshMonitoring()` turns those settings into a `CLCircularRegion` and asks
   Core Location to watch it for *exits only*. If the feature is off, home isn't
   set, or permission is missing, it stops monitoring instead.
4. When you cross the boundary, iOS calls `locationManager(_:didExitRegion:)` —
   relaunching Teddy in the background if it isn't running.
5. `handleExit()` loads the settings and reminders, asks
   `HomeLeaveSettings.shouldNotifyOnLeave` whether this exit qualifies, and if so
   posts an immediate notification via `NotificationScheduler.notifyNow` and
   records the time for the cooldown.

## The pieces

### `Models/HomeLeaveSettings.swift`
The SwiftData model holding home coordinates, radius, on/off, mode, message and
last-sent time. `ensureExists(in:)` fetches the single settings row or creates
it, so every caller can assume it exists. `shouldNotifyOnLeave` and
`hasReminderFiring` are static and take plain values rather than model objects,
which is what lets the tests exercise them without a database.

`hasReminderFiring` reuses `Reminder.upcomingFireDates`, so "within hours" honours
burst slots and Done-today exactly the way the notification scheduler does.

### `Services/LocationMonitor.swift`
A `@MainActor` singleton wrapping `CLLocationManager`. It owns the region,
permission requests, the one-shot `currentLocation()` fix, and the exit handler.
It escalates When-In-Use to Always, because region monitoring only wakes a
closed app with Always permission.

### `Features/Settings/SettingsView.swift`
The form: toggle, message fields, mode picker, and a map with the home circle.
It writes straight to the model through small `Binding`s and calls
`refreshMonitoring()` whenever something that affects the region changes.

### `NotificationScheduler.notifyNow`
Posts a notification with a `nil` trigger, which means "deliver now".

### Project settings
Adds the two location usage strings iOS shows in the permission prompts, and
`UIBackgroundModes = location`.

## Unfamiliar APIs and techniques

- **`CLCircularRegion`** (Core Location) — a circle defined by a centre and a
  radius. Handed to `startMonitoring(for:)`, it becomes a geofence: iOS watches
  it at system level, using cell and Wi-Fi changes rather than constant GPS, so
  it costs almost no battery. `notifyOnEntry = false` / `notifyOnExit = true`
  means only leaving counts.
  [Docs](https://developer.apple.com/documentation/corelocation/clcircularregion)
- **`requestState(for:)`** — asks Core Location to report whether you're
  currently inside or outside the region, so it has a starting state and the
  next crossing is detected correctly.
- **`requestWhenInUseAuthorization` → `requestAlwaysAuthorization`** — iOS only
  lets you ask for Always after When-In-Use has been granted, which is why the
  code asks in two steps.
- **`locationManagerDidChangeAuthorization(_:)`** — called whenever the
  permission changes, including in Settings.app, so monitoring starts or stops
  without reopening the screen.
- **`nonisolated func … { Task { @MainActor in … } }`** — `CLLocationManager`
  calls its delegate methods from outside Swift's actor system. Marking them
  `nonisolated` satisfies the compiler, and the `Task { @MainActor in }` hops
  back onto the main actor before any state is touched.
- **`withCheckedThrowingContinuation`** (Swift concurrency) — turns the
  callback-based `requestLocation()` into something you can `await`. The
  continuation is stored and resumed later by `didUpdateLocations` or
  `didFailWithError`.
- **`UNNotificationRequest(…, trigger: nil)`** (UserNotifications) — a `nil`
  trigger delivers the notification right away.

## Worth knowing

- **Always permission is required for alerts while the app is closed.** With
  When-In-Use only, exits are reported only while Teddy is open, and the
  Settings footer says so.
- Region exits are not instant. iOS usually reports them within a minute or two
  of crossing the line, sometimes later on a weak signal. Radii much under
  ~100 m get unreliable.
- An app may monitor at most 20 regions. Teddy uses one and clears any others
  before adding it.
- The Release build configuration lost
  `INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES` in this change,
  which looks like an accidental Xcode edit. Debug still has it.
