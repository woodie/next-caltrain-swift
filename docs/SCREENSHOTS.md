# App Store Screenshots

Notes on capturing and sizing screenshots for the App Store listing.

## Which simulator

`sim.sh`, `build.sh`, and `test.sh` all boot/target whatever `SIM_DEVICE` is
set to in `sim-device.env` (committed — edit + commit this file when the
screenshot device changes, e.g. moving to a new "Max" model each generation)
or `local.env` (gitignored personal override). Pass `-d/--device NAME` to
any of them to target something else for one run without touching either
file.

## iPhone-only (decided)

This app ships **iPhone-only**. `project.yml` now sets
`TARGETED_DEVICE_FAMILY: "1"` on the `NextCaltrain` target — run `./build.sh`
(wraps `xcodegen generate`) and confirm all 4 occurrences in
`project.pbxproj` read `"1"`, not `"1,2"`, before archiving. No iPad
screenshots or iPad layout testing needed; the layout work in `docs/CLAUDE.md`
("Lessons from layout debugging") is iPhone-specific and was never verified
on iPad, so this also sidesteps that risk.

## Technical requirements (2026)

Apple now scales one screenshot set per device family to every smaller shelf in
that family — you don't need a separate set per individual model.

- **iPhone**: canonical size **1320 x 2868** (6.9", e.g. iPhone 16 Pro Max),
  covers all smaller iPhones down to SE automatically.
- Format: sRGB PNG or JPEG, no transparency.
- Apple's minimum is 1 screenshot per device family, but App Store Connect's
  upload UI effectively wants at least 3 — plan for 3–7 per family.

Our captures (via `sim.sh snap`, see below) come out at the simulator's native
resolution for whichever device you boot — pick an iPhone 16 Pro Max simulator
to land exactly on the canonical size above with no scaling.

**Current `pics/*.png` are not upload-ready**: they're 1206x2622 (iPhone 16
Pro, not Pro Max) and RGBA (alpha channel present) — wrong size and Apple
rejects transparency. Recapture on an iPhone 16 Pro Max simulator, then strip
alpha (e.g. `sips` flatten, or re-save without the alpha channel) before
upload. See `docs/RELEASE.md` for where this fits in the release checklist.

## Capturing a screenshot

From the project root:

```bash
./sim.sh snap                  # saves ~/Downloads/snap-<timestamp>.png
./sim.sh snap my-name.png      # saves ~/Downloads/my-name.png
```

Targets a connected physical device if one's attached (via `idevicescreenshot`),
otherwise falls back to whatever simulator is currently booted. If more than one
physical device is attached, the script lists them and exits rather than guessing.

## Switching light/dark mode

```bash
./sim.sh dark
./sim.sh light
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
`./sim.sh snap`.

**`idevicescreenshot: command not found`**
`brew install libimobiledevice` (only needed for the real-device path; the
simulator path only needs Xcode command line tools).

## Sources

- [App Store Screenshot Sizes 2026 Cheat Sheet](https://medium.com/@AppScreenshotStudio/app-store-screenshot-sizes-2026-cheat-sheet-iphone-16-pro-max-google-play-specs-3cb210bf0756)
- [App Store Screenshot Sizes 2026: Every iPhone & iPad Dimension](https://screenshototter.com/blog/app-store-screenshot-sizes)
- [Apple App Store screenshot sizes & guidelines (2026) — MobileAction](https://www.mobileaction.co/guide/app-screenshot-sizes-and-guidelines-for-the-app-store/)
