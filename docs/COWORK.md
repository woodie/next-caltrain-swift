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

### Test output formatting

`test.sh` pipes through `xcbeautify` (falling back to `xcpretty --test`, then a
raw `grep` filter), then through `tools/test_formatter.py`, which
re-renders the flat per-test lines as an indented describe/context/it tree.

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
process, before being joined into one string and handed to XCTest. So instead
of changing what XCTest/Quick hand to xcbeautify, `test_formatter.py`
post-processes xcbeautify's already-flat text: split each printed name on
`", "`, dedupe the shared prefix against the previous line — the same trick
the Kotlin sibling's Gradle `TestListener` uses (see
`next-caltrain-kotlin/app/build.gradle.kts`) — and re-render as an indented
tree. It runs entirely outside the test process, in the same pipeline slot
xcbeautify/xcpretty already occupy, so there's no risk of stdout getting
captured/mangled by `xcodebuild`.

This is considered done, with three known, deliberate trade-offs:

- **Failing tests aren't folded into the tree.** xcbeautify joins the failure
  reason onto the test name with the same `", "` separator the name already
  uses internally, so there's no recoverable boundary between "name" and
  "reason" in text alone (unlike pass/skip lines, which end in an unambiguous
  `(N seconds)`). Rather than guess at that boundary and risk mangling a
  failure message, a failing line prints verbatim, at the same depth as the
  last known-good leaf, and doesn't update the dedupe state — so the next
  passing test's tree is still computed from the last test that had a real,
  parseable path.
- **Colored output is preserved, not parsed.** xcbeautify only colors the
  glyph and the elapsed-time number (never the test name itself), so the
  script matches and re-emits those tokens — ANSI codes and all — verbatim.
  Verified against both colored and uncolored synthetic fixtures.
- **A bare prose comma inside a single `describe`/`context`/`it` string still
  over-splits into two tree lines.** Quick joins levels with `", "` and no
  escaping, so nothing textually distinguishes a level boundary from a comma
  that's just part of one level's own text. Real examples from this repo's
  specs: `it("is not a transfer, since both endpoints are South County")` and
  `it("today is weekday, tomorrow is weekend")` both print as two stacked
  lines instead of one. `tools/test_formatter.py`'s `split_path()` only
  splits at paren-depth 0, which *does* correctly handle the parenthetical-
  aside style also used in these specs (`context("on a weekday (Wednesday,
  dotw=3)")` prints correctly as one line, comma and all) — but a bare comma
  with no enclosing parens has no equivalent signal, and comparing against
  neighboring tests doesn't help either, since the ambiguous span is usually
  unique to that one test. Confirmed by diffing real `./test.sh` output
  against the actual spec source for every comma-containing description in
  the suite — every parenthetical case rendered correctly, every bare-prose
  case over-split. Closing this gap for good needs Quick's real
  `ExampleGroup.parent` structure instead of its flattened name string (the
  `@testable import Quick` option from the options list above), which is a
  bigger, riskier change than this gap currently justifies.

A blank line is also inserted before every `Test Suite '...' started at ...`
or `Test Suite '...' passed`/`failed at ...` banner, unconditionally — no
exceptions for wrapper suites vs. real specs, no counting nesting depth.
This separates each suite's announcement (`'All tests'`,
`'NextCaltrainTests.xctest'`, each real spec, and the `passed`/`failed`
rollup at the end) from whatever preceded it, including from each other.

Graded A+ now, matching the Kotlin sibling (see its `docs/COWORK.md` "Test
output formatting") modulo the bare-prose-comma caveat above.

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
