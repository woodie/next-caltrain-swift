# Working with Claude on Next Caltrain (iOS)

This repo (`next-caltrain-swift`) is a SwiftUI port of `next-caltrain-pwa` (a JS/PWA
Caltrain schedule app). The `next-caltrain-pwa` repo also hosts a published
`schedule.json` that this app fetches at runtime.

## Edit cycle

Claude has direct read/write access to this repo's working copy and edits files in place
with its file tools — no download/move step. After changes:

```
./build.sh && ./run.sh
```

`./build.sh` wraps `xcodegen` (regenerates the Xcode project — needed when
files are added/removed) + `xcodebuild ... | grep "error:"` (build, only
errors printed) + `xcrun simctl uninstall` (clean reinstall).

`./run.sh` installs and launches the app in the simulator.

After running, the user shares a simulator screenshot for visual feedback and
iteration. Claude commits directly with git when a change is complete — commits go on
`main` and are left unpushed unless asked to push.

## Run tests

```bash
./test.sh
```

Runs `xcodegen generate` then `xcodebuild test` against the `NextCaltrain` scheme
(Quick/Nimble specs in `Tests/`: `GoodTimesSpec`, `CaltrainScheduleSpec`,
`CaltrainServiceSpec`, `TripViewModelSpec`, `ScheduleSpec`).

## Conventions

- **No bold headings/titles** unless explicitly requested. Default to
  `.regular` font weight.
- **Centering ragged content** (rows with variable-width text, e.g. station
  names): use a `PreferenceKey` to measure the max intrinsic width across
  rows, apply `.fixedSize(horizontal: true, vertical: false)` to prevent
  wrapping, fix all rows to that max width (left-aligned within), then center
  the fixed-width column with `.frame(maxWidth: .infinity, alignment: .center)`.
  Use `.offset(x:)` to correct for any asymmetric padding that throws off
  visual centering.
- **Shared styling** lives in `AppStyle.swift`:
  - Font sizes: `fontOriginHero`, `fontStationName`, `fontTripType`, etc.
  - Colors: `Color.calPast`, `.calArrive`, `.calDepart`, `.calSwapped`,
    `.iconCircleBackground`.
  - `AppStyle.iconButtonSize` (44pt) for toolbar icon buttons.
- **Toolbar icons** are circular (`Color.iconCircleBackground` fill,
  `AppStyle.iconButtonSize` frame), used consistently for back/swap/reset
  across Home, TripList, StationSelection, TripDetail, About.

## Schedule data pipeline

- `tools/convert_schedule.py` (in this repo) converts CSVs from
  `../next-caltrain-pwa/data/` into `schedule.json`. Includes a
  `scheduleDate` field (epoch ms = newest source CSV mtime) as a
  freshness/version marker, matching the PWA's convention.
- **No bundled fallback**: the app does not ship `schedule.json` in the
  bundle. On first launch with no cache and a failed/slow fetch, the app
  shows a loading state (see "Startup / loading flow" below) until the
  network fetch succeeds.
- **Published copy**: `../next-caltrain-pwa/webapp/schedule.json` — regenerate
  with `python3 tools/convert_schedule.py ../next-caltrain-pwa/data
  ../next-caltrain-pwa/webapp/schedule.json`, commit, then `npm run deploy`
  from `next-caltrain-pwa` (gcloud App Engine). Served at
  `https://next-caltrain-pwa.appspot.com/schedule.json`.
- At launch, `Schedule.fetchFromNetwork()` fetches the published copy and
  caches it to `Documents/schedule.json` for next launch.
  `Schedule.loadCached()` prefers the cache, validates with `Schedule.isValid`
  (stop lists non-empty, schedule table arrays match stop-list lengths).
- `Schedule.fetchedToday()` / `markFetched()` cap network fetches to once per
  schedule-day (2am boundary, see `GoodTimes.scheduleDateFor` and "Startup /
  loading flow" below) — `lastFetchTime` in `UserDefaults`, key exposed as
  `Schedule.lastFetchKey` for tests.

## Startup / loading flow

- On launch, show a modified `AboutView` as a loading screen: the "Schedule
  data: <date>" section is replaced with "Loading schedule data" (or
  "Unable to load schedule" on permanent failure), and the back button is
  hidden.
- `ContentView` owns the loading state machine (see `loadSchedule()`), now a 3-case
  decision keyed on cache presence *and* whether we already fetched today:
  - **Cache exists and `Schedule.fetchedToday()` is true**: use the cache directly, no
    network call at all — avoids a redundant fetch every time the app is reopened the
    same day.
  - **No valid cache**: block on `Schedule.fetchFromNetwork()`. On success,
    transition to `HomeView`. On failure, show "Unable to load schedule"
    permanently — no retry loop, no transition.
  - **Cache exists but not fetched today**: race `fetchFromNetwork()` against a 10s
    timeout (`firstOf` helper). Whichever resolves first wins; on timeout or
    failure, fall back to the cached schedule and transition to `HomeView`.
- `TripViewModel` no longer loads schedule data itself — it takes a
  `Schedule` via `init(schedule:)`, injected by `ContentView` once loading
  completes.
- See `docs/SCHEDULE_ENDPOINT.md` and `tools/hang_server.py` for how to test
  these states (instant-failure via unreachable port, hanging-server for the
  10s timeout path).

## Debugging approach

- When something looks wrong, **compare side-by-side against the legacy PWA**
  using the same origin/destination — `open ~/next-caltrain-pwa/webapp/index.html`
  (or the live site). The PWA is the reference implementation.
- `git bisect` is available, but be careful: some bugs predate all recent
  commits (i.e. they're not regressions), so bisect can converge on a
  meaningless result. Test the oldest candidate commit directly first if
  unsure whether a bug is a regression at all.
- For routing logic specifically, `next-caltrain-pwa/src/CaltrainService.js`
  is the reference — compare its `direction()`/`select()`/`times()`/`merge()`
  against the Swift `CaltrainService.swift` equivalents when something
  doesn't match.

## Lessons from layout debugging

- **`.navigationBarHidden(true)` on a pushed view (via `NavigationLink`) does
  not preserve the safe-area top inset**, even though the same modifier on a
  root view (like Home) does. A pushed view's content can render flush under
  the status bar/notch despite normal `.padding(.top, ...)`.
  - Symptom: toolbar icons render under the clock and become untappable.
  - Fix that worked: structure the pushed view's body **identically** to the
    working root view — toolbar `HStack` as the literal first child of the
    outermost `VStack(spacing: 0)`, with plain `.padding(.top, 8)`, no extra
    wrapper views, no `GeometryReader`, no `.safeAreaInset`, no
    `.frame(maxHeight:...)`. Matching the structure exactly (not just the
    padding values) is what fixes it — partial matches can still misbehave.
  - Avoid going down the rabbit hole of `.safeAreaInset(edge: .top)`,
    `UIApplication`-derived status bar height, or large fixed padding values
    — these either don't apply, get clipped, or cause the whole view to
    center/bottom-align unexpectedly.

- **Toolbar-vs-content layout pattern**: pin the toolbar as a fixed-height,
  non-flexible `HStack` (no `Spacer()` that could absorb extra space) at the
  top of the outer `VStack`. Put everything else (back button, headers,
  scrollable/list content) in a separate block below it. This avoids fights
  over who "owns" vertical space.

- **Constrain content instead of fighting for header space**: rather than
  squeezing every pixel for a header/toolbar against a content area that
  wants to grow (e.g. a long trip list), cap the content's row count so
  there's natural slack at the bottom. For TripListView, 17 rows fits the
  screen with a little breathing room below.
