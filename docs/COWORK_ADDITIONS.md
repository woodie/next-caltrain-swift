# COWORK ADDITIONS — layout section replacement

Replace the existing "Layout-jump lesson" and "Lessons from layout
debugging" sections with the following. Other sections (Testing, Light/dark
mode, South County, Privacy policy) are unaffected.

---

## Layout patterns (two distinct cases — don't mix them)

There are two different layout problems in this app, with two different
correct solutions. Mixing them up is the most common source of regressions.

### 1. Pushed views (`NavigationLink` destinations) — safe-area jump fix

Any pushed view that shows the *default* iOS nav bar
(`.navigationBarTitleDisplayMode`, no `.navigationBarHidden`) can render
flush-under-the-status-bar on first frame, then jump down once the safe-area
inset resolves — even if it "looks fine" in a screenshot taken after the
jump.

**Fix**: every pushed view follows the same structure as
HomeView/TripListView's *toolbar* — `.navigationBarHidden(true)`, with a
toolbar `HStack` (back button + title/content) as the literal first child of
the outer `VStack(spacing: 0)`, plain `.padding(.top, 8)`. `TripDetailView`
is fixed this way.

For this specific problem: **no `GeometryReader`, no `.safeAreaInset`, no
extra wrapper views, no `.frame(maxHeight:...)`**. Matching the structure
exactly (not just the padding values) is what fixes it — partial matches can
still misbehave. `.safeAreaInset(edge: .top)`, `UIApplication`-derived status
bar height, and large fixed padding values either don't apply, get clipped,
or cause the whole view to center/bottom-align unexpectedly.

### 2. Root-view content layout (HomeView, TripListView) — floating overlay pattern

This is a *different* problem: making the toolbar/header immune to content
size changes, and centering/positioning the main content independently of
the toolbar. The constraints from case 1 do **not** apply here —
`GeometryReader` is the correct tool for this case.

**Pattern**: in the root `ZStack`, give the toolbar/header its own
top-anchored layer, and let the main content float as a separate sibling
layer sized against the full screen:

```swift
ZStack {
    Color.appBackground.ignoresSafeArea()

    // Toolbar/header — own layer, top-anchored, unaffected by content
    VStack(spacing: 0) {
        toolbar
            .padding(.horizontal, 16)
            .padding(.top, 8)
        Spacer()
    }

    // Main content — floats, sized against the full screen
    mainContent
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // or .top
}
```

- **HomeView**: `mainContent` is the circle, with `alignment: .center` — it
  centers on the whole screen regardless of toolbar height.
- **TripListView**: `mainContent` is the trip list, with `alignment: .top`,
  padded down by the header's measured height (see below) so it sits flush
  below the header without overlapping.

#### Measuring header height for row count (TripListView)

TripListView needs to know how many trip rows fit below the header. The
correct approach is:

1. Measure `headerHeight` via a `GeometryReader` in the header's `.background`,
   using both `.onAppear` and `.onChange(of: geo.size.height)`.
2. Read `window.bounds.height` directly from the `UIWindowScene` — **not**
   `UIScreen.main.bounds.height` (which doesn't rotate) and **not** a
   `GeometryReader` on the ZStack (which gets compressed by the row list via
   SwiftUI's layout feedback loop).
3. Compute available height as `window.bounds.height - headerHeight - listTopPad`.

```swift
var windowScene: UIWindowScene? {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
}

var rowCount: Int {
    guard headerHeight > 0, let window = windowScene?.windows.first else { return 1 }
    let available = window.bounds.height - headerHeight - listTopPad
    return min(max(1, Int(available / rowHeight)), viewModel.trips.count)
}
```

**Why not a GeometryReader on the ZStack?** ZStack children influence each
other's sizes in SwiftUI's layout pass. A `GeometryReader` placed as a ZStack
sibling of the row list gets compressed as the row list grows, creating a
feedback loop that causes `rowCount` to oscillate downward. Using
`window.bounds.height` bypasses SwiftUI layout entirely and is immune to
this.

**Why not `UIScreen.main.bounds`?** On iOS 16+, `UIScreen.main.bounds`
returns portrait dimensions regardless of orientation. `window.bounds` rotates
correctly with the device.

#### Row count / overflow (TripListView)

- Use `Int(available / rowHeight)` with no `+1` fudge factor — the
  measurement is accurate enough that flooring is correct.
- Let the list use a `Spacer(minLength: 0)` at the bottom so short lists
  don't stretch rows.

---

## Logging

Swift `print()` goes to stdout and is **not** captured by `xcrun simctl spawn log stream`.
Use `os_log` with a subsystem for logs that need to appear in both Xcode and
the `--log` flag of `run.sh`:

```swift
import os.log

os_log("[TripList] windowHeight=%.1f rowCount=%d",
       log: OSLog(subsystem: "com.netpress.NextCaltrain", category: "TripList"),
       type: .debug,
       wh, rc)
```

The `run.sh --log` predicate filters on `composedMessage CONTAINS "[Tag]"`,
so the bracketed tag in the format string is what makes it visible. Add new
tags to the predicate in `run.sh` when adding new log sites.

---

## What NOT to do (superseded approaches)

- **Don't** use `.safeAreaInset(edge: .top)` to pin the toolbar on
  HomeView/TripListView. It was tried in an earlier session and abandoned —
  it fights with the floating-overlay pattern above and produced incorrect
  row counts and centering.
- **Don't** center the circle/content using `VStack { Spacer(); content;
  Spacer() }` nested inside the toolbar's VStack — toolbar height affects the
  Spacer distribution, so centering is off by the toolbar's height. Use the
  floating-overlay `.frame(maxWidth: .infinity, maxHeight: .infinity,
  alignment: .center)` pattern instead.
- **Don't** use a `GeometryReader` on the ZStack to measure available height
  for row count — ZStack layout feedback compresses it as rows render.
- **Don't** use `UIScreen.main.bounds.height` for orientation-aware height —
  it doesn't rotate on iOS 16+. Use `window.bounds.height` instead.
- **Don't** use `print()` for logs you want to see via `run.sh --log` —
  use `os_log` with a subsystem instead.
