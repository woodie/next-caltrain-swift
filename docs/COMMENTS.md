# Comments

Rationale, history, and design notes that used to live as multi-line
comments in the source. Organized by file, then by the type, property, or
function each note is attached to. The source itself now carries at most
one short line at any given spot -- anything longer that would previously
have been a `///` doc comment or a multi-line `//` note lives here instead.
When a code location kept its own one-line comment, it's noted below so
this stays a complete map of "why," not a duplicate of what's already
readable in the file.

## Sources/CaltrainSchedule.swift

### `Schedule.remoteURL`
Kept a one-line comment in place: "SCHEDULE_URL precedence (local.env >
config.properties > this literal fallback); see docs/COWORK.md "Endpoint
resolution"."

Full history: `remoteURL` reads
`ProcessInfo.processInfo.environment["SCHEDULE_URL"]`, which `sim.sh run`
sets from, highest priority first: `local.env` (gitignored, a
per-developer test override -- the instant-fail/hang-server scenarios
documented in `docs/SCHEDULE_ENDPOINT.md`); then `config.properties`
(committed, the real production URL -- editing and committing that file is
how the schedule endpoint gets relocated, no source change needed); the
literal fallback baked into this property only matters for launches that
bypass `sim.sh run` entirely, e.g. running directly from Xcode. See
`docs/COWORK.md`'s "Endpoint resolution" section for the full three-tier
precedence, which is documented there in full so it doesn't need to be
duplicated at length in source.

### `Schedule.lastFetchKey`
Kept a one-line comment in place: "Not private: tests (@testable import)
read/write this key directly instead of hardcoding the string."

### `Schedule.fetchedToday()`
Kept a one-line comment in place: "True if the last successful fetch
landed on today's schedule-day (2am boundary; see
GoodTimes.scheduleDateFor)."

Full history: exists to skip redundant network calls once today's data is
already fetched. `ContentView.loadSchedule()`'s cache-exists-and-fetched-
today branch (see that file's note below) calls this to decide whether to
skip the network fetch entirely rather than repeating it every time the
app reopens the same day.

### `Schedule.isValid`
Kept a one-line comment in place: "Stop lists are non-empty and every
schedule table's train arrays match their direction's stop-list length."

### `Schedule.fetchFromNetwork()`
Kept a one-line comment in place: "Fetches the latest schedule, caches it
to disk if valid, and returns it; throws on network/decode/validation
failure."

## Sources/ContentView.swift

### `ContentView.loadSchedule()`, cache-exists-and-fetched-today branch
No comment kept in source; judged self-explanatory now -- `if
Schedule.fetchedToday() { schedule = cached; return }` already reads as
exactly what it does.

History: this was "Case 2a" of the three-case loading decision documented
in `docs/COWORK.md`'s "Startup / loading flow" section: cache exists and
`Schedule.fetchedToday()` is true, so the cache is used directly with no
network call at all, avoiding a redundant fetch every time the app is
reopened the same day.

### `ContentView.loadSchedule()`, cache-exists-but-not-fetched-today branch
Kept a one-line comment in place: "Cap the wait at 10s; falls back to the
cached schedule on timeout or failure."

Full history: "Case 2b" of the same three-case decision: cache exists but
hasn't been fetched today, so this races `Schedule.fetchFromNetwork()`
against a 10-second timeout via `firstOf`. Whichever resolves first wins;
on timeout or failure it falls back to the cached schedule and still
proceeds to `HomeView` rather than blocking or erroring -- a failed
refresh here just means trying again next time `loadSchedule()` runs, not
a user-visible failure.

### `ContentView.loadSchedule()`, no-cache branch
No comment kept in source; judged self-explanatory now -- the `do`/`catch`
reads clearly enough that failure sets `loadFailed`.

History: "Case 1" of the three-case decision: no valid cache at all, so
this blocks on `Schedule.fetchFromNetwork()`. On success it transitions to
`HomeView`; on failure it shows a permanent "Unable to load schedule"
state -- deliberately no retry loop, unlike case 2b's next-launch retry.

### `ContentView.firstOf(_:timeout:)`
Kept a one-line doc comment in place: "Races `operation` against a
`timeout` (seconds); returns whichever finishes first."

## Sources/GoodTimes.swift

### `GoodTimes.seeded(dotw:mins:)`
Kept a two-line comment in place explaining the split with `init()`'s
ambient statics -- worth the extra line since it's a real gotcha: a caller
that constructs `GoodTimes` directly should call this, not touch
`dotwSeed`/`minutesSeed`, which exist only so `init()` has something to
fall back to for callers (`TripViewModel`) that build `GoodTimes()`
internally with no way to receive a seed as a parameter.

### `GoodTimes.dotwSeed` / `GoodTimes.minutesSeed`
Formerly `debugOverrideDotw`/`debugOverrideMinutes` -- renamed because
"override" implied a live, continuously-checked effect, when both are
actually read once, at `GoodTimes()` construction time; changing either
afterward does nothing until the next `GoodTimes()` call. "Debug" dropped
too: this is a testing seam, not a developer-debugging tool. Both `nil`
by default; used by `TripViewModelSpec` to pin the clock/day-of-week
`TripViewModel` reads internally, always reset in `afterEach` so neither
leaks between specs.

### `GoodTimes.didLog`
No comment kept in source; judged self-explanatory now given the one-liner
already on `seeded(dotw:mins:)` above it establishes the testing-seam
context.

History: gates `logOnce(_:)` so the computed `GoodTimes` values print to
console only once per process, on the first construction -- useful when
testing with a seed set, to confirm it actually took effect, without
flooding the console on every timer tick.

### `GoodTimes.scheduleDateFor(_:)`
Kept a one-line doc comment in place: "Schedule-day (yyyy-MM-dd) for
`date`, using the same "day starts at 2am" rule as `init()`."

Full history: subtracts 2 hours before formatting, same as `init()` does,
so a timestamp from 1am counts as belonging to the previous calendar day's
schedule. Exists specifically so `Schedule.fetchedToday()` can compare
"today" against a stored last-fetch timestamp for the once-per-day
schedule fetch policy described in `docs/COWORK.md`.

## Sources/StationSelectionView.swift

### `StationSelectionView.stationListBody(stations:selected:columnWidth:onSelect:)`
Kept a one-line comment in place: "ScrollView + VStack (not
List/LazyVStack): avoids List's minimum-row-height floor and LazyVStack's
unbounded height proposal."

Full history: `List` (UITableView-backed) enforces its own minimum row
height even with `defaultMinListRowHeight` zeroed out, so rows stay taller
than the content actually needs. `LazyVStack` was tried next, but it takes
a generous/unbounded height proposal from its enclosing `ScrollView` that
ignores actual content size -- likely why shrinking `stationRow`'s `Text`
never changed row pitch when this was tried. Plain `VStack` inside
`ScrollView` has no such floor and sizes each row to exactly insets + text
height; laziness isn't needed here since the station list is short, ~30
rows max.

### `StationSelectionView.stationListBody(...)`, `.onAppear` modifier
Kept a one-line comment in place: "DispatchQueue.main.async: List's
scrollTo "just worked" on appear, but plain VStack needs the layout pass
to finish first or this silently no-ops."

Full history: with `List`, calling `proxy.scrollTo` directly inside
`.onAppear` worked without any extra dispatch. The plain `VStack` used
here (see the note above on why `List`/`LazyVStack` were dropped) needs
the initial layout pass to finish first, or `scrollTo` fires before the
scroll view knows each row's offset and silently no-ops -- leaving the
list scrolled to the top instead of centered on the selected station.
Wrapping the call in `DispatchQueue.main.async` defers it just long enough
for that first layout pass to complete.

## Sources/TripViewModel.swift

### `TripViewModel.dayMinutes`
Kept a one-line doc comment in place: "Minutes-since-midnight offset
applied to "tomorrow"'s trips (see `Trip.isFuture`)."

Full history: this offset is applied to "tomorrow"'s trips so their
depart/arrive times sort after today's and produce correct countdowns;
trips from the appended block are marked via `Trip.isFuture`.

### `TripViewModel.tomorrowScheduleType`
Kept a one-line doc comment in place: "Schedule type for tomorrow's date,
used for trips appended after today's."

Full history: identified by `Trip.depart >= TripViewModel.dayMinutes` --
i.e. any trip whose depart time was shifted forward by the "tomorrow"
offset uses this schedule type instead of today's `scheduleType` when
looking up its stop times.

### `TripViewModel.isFutureSelected`
Kept a one-line doc comment in place: "True if the currently-selected trip
belongs to the appended "tomorrow" block."

### `TripViewModel.init(schedule:)`
Kept a one-line doc comment in place: "`sched` is loaded by ContentView
during startup (cache or network) and injected here."

Full history: `TripViewModel` no longer loads schedule data itself;
`ContentView` owns the loading state machine (see `docs/COWORK.md`'s
"Startup / loading flow") and injects the resolved `Schedule` once loading
completes, whether that schedule came from disk cache or a fresh network
fetch.

### `TripViewModel.shiftedToTomorrow(_:)`
Kept a one-line doc comment in place: "Returns `trip` with legs/arrival
shifted forward by `dayMinutes`, representing a "tomorrow" trip."

### `TripViewModel.clampedOffset(preferring:)`
Kept a one-line doc comment in place: "Falls back to the first trip if
there's no service tomorrow and today's trips are all in the past."

Full history: shared fallback used by both `refresh()` and
`updateNextIndex()`: if there's no service tomorrow and today's trips have
all already departed, this keeps the *first* trip of the day selected
instead of clamping to the last (already-departed) one, which would
otherwise leave a stale, already-gone trip highlighted.

## Tests/GoodTimesSpec.swift

### `describe(".scheduleDateFor(_:))`
Kept a one-line comment in place: "Both timestamps in each test use the
same Calendar so the comparison holds regardless of device timezone."

Full history: this group covers `GoodTimes.scheduleDateFor(_:)`, used by
the once-per-day schedule fetch cap (`Schedule.fetchedToday()`) to decide
whether a stored "last fetched at" timestamp still counts as "today" under
the same "day starts at 2am" rule `GoodTimes()` itself uses. Building both
timestamps in each test from the same `Calendar` instance is what makes
the comparison hold regardless of the device's default timezone.

## Tests/ScheduleSpec.swift

### `ScheduleSpec` (class)
Kept a one-line doc comment in place: "Covers Schedule.fetchedToday(), the
once-per-day fetch cap; 2am boundary math itself is covered in
GoodTimesSpec."

Full history: `fetchedToday()` itself only reads `UserDefaults` and
delegates to `GoodTimes.scheduleDateFor()` for the actual "is this still
today" math -- this spec exercises the `UserDefaults`-reading/delegation
behavior, while the 2am-boundary date math is covered separately in
`GoodTimesSpec`'s `.scheduleDateFor(_:)` group, so the two aren't
duplicated.

## Tests/SpecFixtures.swift

### `SpecFixtures` (enum)
Kept a one-line doc comment in place: "Factory for building `Schedule`
fixtures for specs; see docs/COMMENTS.md for station layout and usage."

Full history: `TripViewModel.init` defaults to `stopAM = 15` / `stopPM =
0` when no saved preferences exist (matching the real schedule's station
count), so fixture stop lists must have at least 16 entries or `init`
crashes with an out-of-bounds array access.

The four stations that matter for routing/transfer logic are placed at
the ends and at meaningful interior positions; everything else is filler
("Stop N") that no spec references directly:

    index:    0              1..6      7                 8..13      14           15
    station:  San Francisco  Stop 1-6  San Jose Diridon  Stop 7-12  Morgan Hill  Gilroy

"South" means increasing index (SF -> Gilroy), matching
`CaltrainService.direction`. Electric trains (IDs 100-700) only run SF <->
San Jose Diridon, since Caltrain doesn't own the electrified tracks south
of there. Diesel/South County trains (IDs 800-900) only run San Jose
Diridon <-> Gilroy. Any SF <-> Morgan Hill/Gilroy trip therefore requires
a transfer at San Jose Diridon, while a Morgan Hill <-> Gilroy trip is
direct (no transfer).

With the default indices (stopAM=15, stopPM=0), a freshly-initialized
`TripViewModel` defaults to Gilroy <-> San Francisco -- a transfer route
-- which is convenient for rollover/offset specs.

Building a schedule:

    let schedule = SpecFixtures.schedule {
        $0.weekday(electric: .normal, diesel: .normal)
        $0.weekend(electric: .normal, diesel: .none)
        $0.holiday(electric: .normal, diesel: .none)
    }

Each leg (electric/diesel) for each schedule type can be `.normal` (the
default timetable), `.none` (no trains -- e.g. South County on weekends),
or `.custom([...])` for hand-specified times.

### `SpecFixtures.stops`
Kept a one-line doc comment in place: "Index order: SF=0 ... Gilroy=15
(South = increasing index), with filler stations padding to >= 16
entries."

### `SpecFixtures.schedule(_:)`
Kept a one-line doc comment in place: "Builds a `Schedule`; any
unconfigured schedule type defaults to `.none` for both legs (empty
table)."

Full history: matches how real "no service" days behave -- a schedule type
that's never configured via the closure just ends up with empty tables,
same as a real day with no trains running.

### `SpecFixtures.weekdayOnlySchedule()`
Kept a one-line doc comment in place: "Convenience: normal weekday service
only, no weekend/modified service (the most common fixture shape)."

### `SpecFixtures.Builder.emptyRow(north:setting:)`
Kept a one-line doc comment in place: "Builds a `[Int?]` of length
`stopCount`; `north` converts indices into `northStops`' reverse order."

## Tests/TripViewModelSpec.swift

### `context("for a future trip's schedule type (Friday -> Saturday)")`
Kept a one-line comment in place: "Friday with weekday+weekend service:
today's trips all departed, tomorrow is Saturday (.weekend)."

Full history: this context verifies that `TripListView`/`TripDetailView`
should use `tomorrowScheduleType`, not `scheduleType`, when displaying a
trip that belongs to the appended "tomorrow" block -- see the
`it("correct schedule type for detail view is tomorrowScheduleType")`
example below it.

### `context("for a route with no service on any day")`, empty configure closure
No comment kept in source; the empty closure body plus the surrounding
context name ("for a route with no service on any day") already makes
clear nothing is configured.

History: previously had a two-line comment reiterating "intentionally
empty: no service configured for any schedule type" inside the closure
body -- redundant with the context name one level up, so dropped.

### `context("manual selection via setOffset")`
Kept a one-line comment in place: "Regression coverage for the
reset-button-stuck-on bug: dragging back to the next-train offset should
clear hasManualSelection."

Full history: covers a bug where dragging away from the next train set
`hasManualSelection` (showing the reset button), but dragging back to that
same next-train offset failed to clear it again -- leaving the reset
button visible even though the current selection was exactly the
auto-picked "next train."
