# Working with Next Caltrain (iOS)

This repo (`next-caltrain-swift`) is a SwiftUI port of `next-caltrain-pwa` (a JS/PWA
Caltrain schedule app). The `next-caltrain-pwa` repo also hosts a published
`schedule.json` that this app fetches at runtime.

## Edit cycle

Cowork has direct read/write access to this repo's working copy and edits files in place
with its file tools — no download/move step. After changes:

```
./build.sh && ./run.sh
```

`./build.sh` wraps `xcodegen` (regenerates the Xcode project — needed when
files are added/removed) + `xcodebuild ... | grep "error:"` (build, only
errors printed) + `xcrun simctl uninstall` (clean reinstall).

`./run.sh` installs and launches the app in the simulator. By default it
preserves existing app data (cache, UserDefaults) across runs, forcing only a
cold relaunch (`simctl terminate` + `install` + `launch`) — pass `--fresh`/`-f`
for a full wipe (`simctl uninstall` first, same as `./build.sh` already does).
See `docs/SCHEDULE_ENDPOINT.md` for when each matters.

After running, the user shares a simulator screenshot for visual feedback and
iteration. Cowork commits directly with git when a change is complete — commits go on
`main` and are left unpushed unless asked to push.

**Bugfixes and features tied to a GitHub issue go on a branch, not straight to
`main`.** Create `bugfix/<issue>-<slug>` or `feature/<issue>-<slug>`, make the fix
there, and stop — do not commit (even to the branch) until the user has discussed
the fix and confirmed it actually works (ran `./test.sh`, tried it in the
simulator). Committing before that confirmation is exactly what we're avoiding;
the user pushes, reviews, and merges into `main` themselves once satisfied.
Direct-to-`main` commits are still fine for changes that don't need that
back-and-forth (docs, copy, config).

## Run tests

```bash
./test.sh
```

Runs `xcodegen generate` then `xcodebuild test` against the `NextCaltrain` scheme
(Quick/Nimble specs in `Tests/`: `GoodTimesSpec`, `CaltrainScheduleSpec`,
`CaltrainServiceSpec`, `TripViewModelSpec`, `ScheduleSpec`).

To run a single spec class, pass `-only-testing` through — `test.sh` forwards
any extra args straight to `xcodebuild test`:
```bash
./test.sh -only-testing:NextCaltrainTests/GoodTimesSpec
```
Matches the Kotlin sibling's `./test.sh --tests "*.GoodTimesSpec"` (its
`docs/COWORK.md`/`docs/DEVELOPMENT.md`), which forwards args to `gradlew` the
same way.

### Test output formatting

`test.sh` pipes `xcodebuild test`'s raw output directly into
[`xctidy`](https://github.com/woodie/xctidy), a standalone Swift CLI that
re-renders the flat per-test lines as an indented describe/context/it tree.
`test.sh` fails fast with an install hint if `xctidy` isn't on `PATH`.

The flatness is a real limitation of XCTest/Quick, not just a formatter
choice — confirmed by reading Quick's source
(`Sources/Quick/Examples/Example.swift`, `ExampleGroup.swift`,
`TestSelectorNameProvider.swift`): Quick flattens every `it()` into its own
XCTestCase method on the spec class, so XCTest only ever sees one Suite (the
class) with N flat Cases — there's no nested-suite structure for any
XCTest-based tool (xcbeautify, xcpretty, `xcresulttool`, Xcode's own test
navigator) to recover. `Example.name` — the comma-joined describe/context/it
chain — is literally promoted to the test's method-selector name by default.
The nesting only exists as `ExampleGroup.parent` pointers inside Quick's own
process, before being joined into one string and handed to XCTest.

`xctidy` started life as `tools/test_formatter.py`, a Python script in this
repo that post-processed `xcbeautify`'s already-flat text: split each
printed name on `", "`, dedupe the shared prefix against the previous line
— the same trick the Kotlin sibling's Gradle `TestListener` uses (see
`next-caltrain-kotlin/app/build.gradle.kts`). That worked, but had to guess
at the describe/context/it boundary from text `xcbeautify` had already
reshuffled. `xctidy` is a from-scratch Swift rewrite that instead reads
`xcodebuild`'s raw output directly — the same protocol `xcbeautify`/
`xcpretty` both parse, no dependency on either — which closes a gap
`test_formatter.py` couldn't:

- **Failing tests are now folded into the tree.** `test_formatter.py`
  couldn't recover the boundary between a failing test's name and its
  failure reason once `xcbeautify` had already joined them with the same
  `", "` separator the name uses internally, so a failing line printed
  verbatim, un-deduped, at the last known-good leaf's depth.  `xctidy`
  reads the raw `error:` line itself, before anything else has touched it,
  so it cleanly separates name from reason and folds the failure into a
  `Failures:` section at the end, the way RSpec does.
- **Colored output is preserved**, same as before — the glyph and
  elapsed-time coloring carry through unchanged.
- **The comma-disambiguation approach is unchanged**, just reimplemented
  natively: `xctidy` reads every describe/context/it string literal
  directly out of `Tests/*.swift` and uses that set as a dictionary to
  decompose a flattened name (the same fix that closed the bare-prose-comma
  over-split bug here, e.g. `it("is not a transfer, since both endpoints
  are South County")`), falling back to paren-depth-0 splitting only when a
  name can't be uniquely resolved that way.

See [xctidy's docs/HOW_IT_WORKS.md](https://github.com/woodie/xctidy/blob/main/docs/HOW_IT_WORKS.md)
for the full rendering mechanism (styles, footer, known limitations).
`tools/test_formatter.py` is retired and no longer referenced by `test.sh`.

This produces the same kind of indented tree as the Kotlin sibling (see its
`docs/COWORK.md` "Test output formatting").

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
- **Published copy**: `../next-caltrain-pwa/feed/schedule.json` — regenerated
  by `update_json.py` in `next-caltrain-pwa` (the CSV→JSON conversion moved
  there; see "Update (2026-06-18)" note in `docs/GIT_WORKFLOW.md`), then
  `npm run deploy` (gcloud App Engine). Served at
  `https://next-caltrain-pwa.appspot.com/feed/schedule.json`. (A separate,
  hand-frozen `next-caltrain-pwa/webapp/schedule.json` is served at the
  legacy `/schedule.json` URL solely for the iOS 1.0 App Store review build
  — see that repo's `docs/PUBLISHING.md` "Schedule JSON URLs" section.)
- **Endpoint resolution**: `Schedule.remoteURL` reads `ProcessInfo.processInfo.environment["SCHEDULE_URL"]`,
  which `run.sh` sets with this precedence (highest first):
  1. `local.env` (gitignored) — per-developer override, e.g. the instant-fail/hang-server
     test scenarios in `docs/SCHEDULE_ENDPOINT.md`. Never committed.
  2. `schedule-endpoint.env` (committed, repo root) — the real production URL. If the
     schedule data ever moves to a new home, edit and commit this file directly, no
     source edit needed.
  3. The literal in `CaltrainSchedule.swift` — last-resort safety net for launches that
     bypass `run.sh` (e.g. running directly from Xcode).
  Switching endpoints via either `.env` file is just an edit + `./run.sh`, no rebuild.
  (Kotlin sibling uses the equivalent `scheduleUrl=` layering across `local.properties` /
  `schedule-endpoint.properties`.)
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
