# App Store Screenshots

Notes on capturing and sizing screenshots for the App Store listing.

## iPhone vs. iPad — check this first

This app's `TARGETED_DEVICE_FAMILY` is `"1,2"` (project.pbxproj) — it's built as a
**universal app supporting both iPhone and iPad**. Apple requires screenshots for
every device family a build supports, so as-is, **iPad screenshots are mandatory**,
not optional, before this can be submitted.

The layout work documented in `docs/CLAUDE.md` ("Lessons from layout debugging") is
all iPhone-specific (status bar/notch, toolbar sizing) — there's no evidence the UI
has been verified on an iPad screen size/aspect ratio. Before taking screenshots,
decide:
- **Restrict to iPhone-only**: set `TARGETED_DEVICE_FAMILY = "1"` in the Xcode
  project (all 4 occurrences in `project.pbxproj`, or via `project.yml` +
  `xcodegen generate` if a device-family setting is added there instead) and
  resubmit as iPhone-only. No iPad screenshots needed.
- **Keep iPad support**: verify the layout actually looks right on an iPad
  simulator first, then capture iPad screenshots too (see sizes below).

## Technical requirements (2026)

Apple now scales one screenshot set per device family to every smaller shelf in
that family — you don't need a separate set per individual model.

- **iPhone**: canonical size **1320 x 2868** (6.9", e.g. iPhone 16 Pro Max),
  covers all smaller iPhones down to SE automatically.
- **iPad** (only if keeping iPad support): canonical size **2064 x 2752**
  (13" iPad Pro), covers other iPad sizes automatically.
- Format: sRGB PNG or JPEG, no transparency.
- Apple's minimum is 1 screenshot per device family, but App Store Connect's
  upload UI effectively wants at least 3 — plan for 3–7 per family.

Our captures (via `snap.sh`, see below) come out at the simulator's native
resolution for whichever device you boot — pick an iPhone 16 Pro Max simulator
(and, if applicable, a 13" iPad Pro simulator) to land exactly on the canonical
sizes above with no scaling.

## Capturing a screenshot

From the project root:

```bash
./snap.sh                  # saves ~/Downloads/snap-<timestamp>.png
./snap.sh my-name.png      # saves ~/Downloads/my-name.png
```

Targets a connected physical device if one's attached (via `idevicescreenshot`),
otherwise falls back to whatever simulator is currently booted. If more than one
physical device is attached, the script lists them and exits rather than guessing.

## Switching light/dark mode

```bash
./snap.sh -dark
./snap.sh -light
```

**Simulator only** — this runs `xcrun simctl ui booted appearance`. iOS has no
public command-line API to toggle Dark Mode on a physical device, so on real
hardware the script just prints the manual steps (Settings > Display &
Brightness, or Control Center) instead of failing silently.

## Troubleshooting

**"More than one physical device attached"**
Disconnect the one you don't want to capture from, or boot a simulator instead.

**Empty/failed screenshot**
Make sure the device/simulator screen is on and unlocked before running
`./snap.sh`.

**`idevicescreenshot: command not found`**
`brew install libimobiledevice` (only needed for the real-device path; the
simulator path only needs Xcode command line tools).

## Sources

- [App Store Screenshot Sizes 2026 Cheat Sheet](https://medium.com/@AppScreenshotStudio/app-store-screenshot-sizes-2026-cheat-sheet-iphone-16-pro-max-google-play-specs-3cb210bf0756)
- [App Store Screenshot Sizes 2026: Every iPhone & iPad Dimension](https://screenshototter.com/blog/app-store-screenshot-sizes)
- [Apple App Store screenshot sizes & guidelines (2026) — MobileAction](https://www.mobileaction.co/guide/app-screenshot-sizes-and-guidelines-for-the-app-store/)
