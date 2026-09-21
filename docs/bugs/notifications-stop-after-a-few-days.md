# Reminder notifications stop after a few days

## What was wrong

**Symptom:** reminders fire fine for a day or two, then all go quiet. Opening
Teddy from scratch brings them back for a while.

**Defect:** commit `7694fd7` (mark reminders Done) switched
`NotificationScheduler.schedule` from one *repeating* daily trigger per burst
slot to *one-off* triggers for specific dates. Those dates came from
`upcomingFireDates`, which only looks `Reminder.scheduleLookAheadDays = 3` days
ahead. The only thing that topped the queue back up was
`NotificationScheduler.resyncAll` inside `RootView`'s `.task`, and that only
runs when the app launches from cold.

## Why it wasn't working

1. You open Teddy on Monday. It queues one-off notifications for Monday, Tuesday
   and Wednesday, and nothing after that.
2. You close it. iOS suspends the app but usually keeps it in memory.
3. On Tuesday you open it from the app switcher. That's a return from the
   background, not a fresh launch, so `.task` doesn't run again and nothing new
   is queued.
4. Wednesday's last notification fires, and after that nothing is queued. From
   Thursday on there are no notifications.

It looked random because it depended on how iOS treated the app. If iOS happened
to kill Teddy in the background, the next open was a cold launch, the queue got
refilled, and you'd get another three days. If Teddy stayed in memory, the
three days ran out.

## Why the fix works

The fix goes back to repeating triggers, which iOS fires every day without the
app ever running. Done still works:

- **Normal day:** each burst slot gets one trigger matching just *hour:minute*
  with `repeats: true`. It fires every day indefinitely.
- **Done today:** today's slots must not fire again today, but a daily repeat
  can't skip a day. So each slot gets six *weekly* repeating triggers, one for
  each weekday except today, plus a one-off for this same weekday next week.
  Everything except today keeps working without the app.
- **Next time the app comes forward** (`RootView` now resyncs on every
  `scenePhase == .active`, not just on launch), Done-today no longer applies
  and the slots go back to one daily trigger each.

Walking the old failure through: open on Monday, don't touch it for a week.
Every slot has a daily repeating trigger, so Thursday, Friday and every day
after still fire. If you tapped Done on Monday, Tuesday through Sunday fire from
the weekly triggers and next Monday fires from the one-off. The only way to
lose anything is to go more than a week after a Done without opening Teddy or
tapping Done again. Even then you only lose that one weekday's slots.

**How I know:** new unit tests cover `ReminderSchedule.plannedNotifications`:
daily repeats when not done, all weekdays except today plus a +7-day one-off
when done, and nothing when disabled. I haven't reproduced the multi-day
failure on a device. The diagnosis comes from reading the code, and the timing
of the old code matches the symptom exactly.

## Why it wasn't caught

The tests covered *which dates* `upcomingFireDates` returned, not *how long the
queue lasts*. Testing on-device usually means rebuilding from Xcode, which is a
cold launch every time, so the queue got refilled on every run and never ran
out.

## Unfamiliar APIs and techniques

- **`UNCalendarNotificationTrigger(dateMatching:repeats:)`** (UserNotifications) —
  fires when the current date matches the components you give it. The
  components you *leave out* are what make it repeat: `hour` + `minute` matches
  every day, and adding `weekday` matches once a week. With `repeats: false` it
  fires once and is removed.
  [Docs](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)
- **`weekday` in `DateComponents`** — 1 is Sunday through 7 is Saturday in the
  Gregorian calendar, regardless of which day the user's week starts on.
- **`@Environment(\.scenePhase)`** (SwiftUI) — `.active`, `.inactive` or
  `.background`. `.onChange(of: scenePhase)` runs every time the app comes to
  the front, which `.task` doesn't: `.task` runs once when the view first
  appears.

## Worth knowing

- **The tempting wrong fix** is to raise `scheduleLookAheadDays` to 14 or 30.
  iOS keeps at most 64 pending notifications per app, so a few reminders with
  bursts would push past that, and iOS would drop requests without telling you.
  It would also only delay the cliff, not remove it.
- The 64 limit still applies. A repeating trigger counts once, so a normal day
  costs one per burst slot. A Done day costs seven per slot for that reminder.
  Ten reminders with 10-slot bursts would go over.
- `upcomingFireDates` is still used by leave-home "within hours" mode, which
  needs real dates, not triggers. It's no longer used for scheduling.
- A burst that runs past midnight (say 23:40 + 20 min) wraps to 00:00. The
  scheduler treats that as the same weekday, as the old code did.
