# Today/Tomorrow Trip Rollover

## What this feature does

`TripViewModel.trips` now contains **two days of trips concatenated**:

```
trips = todayTrips + tomorrowTrips
```

- `todayTrips` = `service.routes(..., scheduleType: scheduleType)` — today's
  schedule, exactly as before.
- `tomorrowTrips` = `service.routes(..., scheduleType: tomorrowScheduleType)`,
  with every trip's `depart`/`arrive` (and each leg's `depart`) shifted
  forward by `TripViewModel.dayMinutes` (1440), and `isFuture: true` set on
  the `Trip`.

This lets the user scroll/swipe past the end of today's schedule into
tomorrow's, see tomorrow's trains (in "inactive" blue/gray styling, no
countdown), and select one as "next" if it's currently the actual next train
(e.g. it's 1:30am and today's trains are all gone).

## Key pieces

### `GoodTimes.swift`
- `tomorrowDate` / `tomorrowDotw`: date string and day-of-week for "tomorrow"
  (i.e. `run + 1 day`, where `run = now - 2hr`). Used to look up tomorrow's
  `ScheduleType` via `CaltrainSchedule.optionIndex`, so a Friday→Saturday or
  weekday→holiday transition is handled correctly.
- `partTime(_:)` now does `(minutes / 60) % 24` for the hour, so it correctly
  formats both:
  - today's native post-midnight values (e.g. `1445` = 24:05 = "12:05am"), and
  - tomorrow's shifted values (e.g. `1740` = 29:00 → 29%24=5 → "5:00am").
- **Test seeds**: prefer `GoodTimes.seeded(dotw:mins:)` wherever the caller
  constructs `GoodTimes` directly -- resolved straight from the arguments,
  nothing global to reset afterward.
  - `dotw: Int?` — force "today" to a specific day-of-week (0=Sunday...
    6=Saturday). `tomorrowDotw` is derived from this (`(dotw + 1) % 7`), so
    e.g. `seeded(dotw: 5)` (Friday) makes `tomorrowDotw = 6` (Saturday →
    weekend schedule for tomorrow).
  - `mins: Int?` — force "now" to a specific minutes-since-midnight value.
  - For specs driving `TripViewModel` (which constructs `GoodTimes()`
    internally, with no seam to pass a seed through), set the
    `GoodTimes.dotwSeed`/`GoodTimes.minutesSeed` statics instead, and
    **remember to set both back to `nil` in `afterEach`** -- that path is
    genuine global state.

### `CaltrainService.swift`
- `Trip` gained `var isFuture: Bool = false` (default, so existing call sites
  inside `CaltrainService` are unaffected). This is the **only** source of
  truth for "is this trip part of the appended tomorrow block."
- **Do not** try to infer "future" from `depart >= 1440`. Today's own
  late-night trains are legitimately encoded as `24:0x`–`25:5x` (1440-1559),
  so that range is NOT exclusive to tomorrow's shifted trips. This was a real
  bug (see "History" below) — `isFuture` exists specifically to avoid it.

### `TripViewModel.swift`
- `static let dayMinutes = 1440` — the shift amount applied to tomorrow's
  trips. Only used for the *shift*, not for classification.
- `tomorrowScheduleType: ScheduleType` — computed from `goodTimes.tomorrowDate`
  / `tomorrowDotw` via `CaltrainSchedule.optionIndex`. Independent of the
  user's `scheduleType` (so `cycleSchedule()` only affects today's portion;
  tomorrow's schedule type reflects the real calendar regardless).
- `shiftedToTomorrow(_:)` — produces a copy of a `Trip` with all leg-departs
  and `arrive` shifted by `+dayMinutes`, and `isFuture: true`.
- `refresh()` — builds `trips = todayTrips + tomorrowTrips.map(shiftedToTomorrow)`.
  `nextIndex`/`offset` logic is otherwise unchanged; it works because:
  - today's `depart` values are always `< goodTimes.minutes`'s effective
    ceiling once "expired" (so `nextIndex` finds them via `depart >= minutes`)
  - tomorrow's *shifted* `depart` values (≈1440 + tomorrow's table value, e.g.
    1440+290=1730 for a 5am train) are always `> 1559`, i.e. always
    `> goodTimes.minutes` (max ~1559) — so they're always "in the future" from
    `nextIndex`'s perspective, and `nextIndex` naturally rolls into them once
    today's trips are exhausted.
- `isFutureSelected: Bool` — `trips[offset].isFuture`. (Currently informational
  / available for use; HomeView and TripListView each have their own local
  `isSelectedFuture` computed the same way via `selectedTrip?.isFuture`.)

### `TripListView.swift` / `HomeView.swift`
- `isSelectedFuture` — `selectedTrip?.isFuture ?? false`.
- Status/blurb text: if `isSelectedFuture`, show
  `"\(viewModel.tomorrowScheduleType.label) Schedule"` (e.g. "Weekend
  Schedule") instead of a countdown — same treatment as `isSelectedPast`/
  `swapped`, but using **tomorrow's** schedule type for the label.
- `statusColor` / `infoColor` / ring color: future trips get the same
  "inactive" blue (`.calPast`) treatment as past trips for text.
- **Selection ring/border exception**: if the *selected/next* trip is a future
  trip (`isNext && isFuture`), the ring/border is still **green**
  (`.calArrive`), not gray — because it genuinely is "the next train," just
  displayed with inactive-styled text. This is why `TripRow` has both
  `isInactive` (was `isPast`) and `isFuture` as separate flags:
  - `isInactive` → text color (blue if true, white otherwise)
  - `isFuture` (only checked when `isNext`) → border color override to green

### `TripRow.swift`
- `isPast` renamed to **`isInactive`** — covers both "genuinely past" and
  "future/tomorrow" trips, both of which render with blue text
  (`.calPast`) instead of white.
- `isFuture: Bool` — new flag, only affects `borderColor` when `isNext` is
  also true (next+future → green ring, not gray).

## History / known-fixed bugs

1. **SC-to-SC transfer false positive** (commit `8b1355d` and its revert):
   the old `needsTransfer` check fired for *any* trip touching a South County
   station, including SC-to-SC trips that need no transfer. Fixed by requiring
   `departIsSC != arriveIsSC` (exactly one endpoint in South County).

2. **`isFuture` misclassification via `depart >= 1440`** (fixed in this
   feature's development): today's own post-midnight trains (e.g. a 12:05am
   train encoded as `1445`) were being misclassified as "tomorrow" because
   `1445 >= 1440`. Fixed by using an explicit `Trip.isFuture` flag instead of
   inferring from `depart`'s magnitude.

## Things to watch for / re-verify if something looks wrong

- If a "next" train shows the wrong color ring, check whether `isFuture` is
  being computed/passed correctly — it should only be `true` for trips in the
  appended tomorrow block, never for today's late-night trains.
- If times display wrong (e.g. "29:00" instead of "5:00am"), check
  `GoodTimes.partTime`'s `% 24`.
- If the wrong schedule type is shown for tomorrow's trips (e.g. weekday
  instead of weekend on a Friday night), check `tomorrowScheduleType` and
  `goodTimes.tomorrowDate`/`tomorrowDotw`, and verify `specialDates` /
  `optionIndex` are being consulted for *tomorrow's* date, not today's.
- `cycleSchedule()` intentionally does NOT affect `tomorrowScheduleType` —
  if you manually view "Modified" for today, tomorrow's appended trips still
  reflect tomorrow's real calendar schedule. This is by design but can look
  inconsistent if not expected.
- The `dotwSeed`/`minutesSeed` statics (for `TripViewModel`-driven specs) live
  in `GoodTimes.swift` and must both be reset to `nil` before shipping/committing.
  Specs that construct `GoodTimes` directly should use `seeded(dotw:mins:)`
  instead, which has nothing to reset.
