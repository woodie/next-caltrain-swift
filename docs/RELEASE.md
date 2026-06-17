# Release Runbook — Next Caltrain (iOS)

## When to use this

Any time you're publishing a build to the Apple App Store: the very first
submission, or a routine update to an already-live listing.

## Prerequisites and access needed

- **Apple Developer Program membership** — confirmed active ($99/yr,
  auto-renews). If it ever lapses, re-enrollment approval is typically 1–3
  days for an individual account.
- **Xcode 26+ / iOS 26 SDK.** Mandatory for every upload since April 28,
  2026 — Apple rejects builds made with an older SDK at the upload step.
  Check with `xcodebuild -version` before archiving.
- **Signing** — `DEVELOPMENT_TEAM = 754T277KBJ` is already wired into
  `project.yml` (and regenerated into `project.pbxproj` by `xcodegen`), using
  Automatic Signing. Unlike the Android keystore, there's no local secret
  file to lose — certificates live in the Apple Developer account and can be
  revoked/reissued from there if needed (see Escalation).
- **Store listing copy** — `docs/APP_STORE_LISTING.md` (name, subtitle,
  description, keywords, category, age rating notes, privacy policy URL).
- **Privacy policy** — already live: https://next-caltrain-pwa.appspot.com/privacy.html
  (shared with the Android sibling app).
- **Screenshots** — iPhone-only (decided, see below). Current `pics/*.png`
  are **not** upload-ready: wrong size (1206x2622, not the 1320x2868
  canonical) and carry an alpha channel Apple rejects. Recapture before
  first submission — see `docs/SCREENSHOTS.md`.
- **App icon** — `assets/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`,
  1024x1024 RGB, ready as-is.

## One-time account & app setup (skip once done)

1. **Device family — decided: iPhone-only.** `project.yml` sets
   `TARGETED_DEVICE_FAMILY: "1"` on the `NextCaltrain` target. Run
   `./build.sh` (wraps `xcodegen generate`) and confirm all 4 occurrences in
   `project.pbxproj` read `"1"`, not `"1,2"`, before archiving. This avoids
   the iPad-screenshot requirement and the never-verified iPad layout risk
   noted in `docs/SCREENSHOTS.md`.
2. **Register the Bundle ID** (if not already): developer.apple.com/account →
   Identifiers → confirm `com.netpress.NextCaltrain` is registered. It may
   already exist from local device signing — check before assuming you need
   to create it.
3. **App Store Connect → My Apps → + → New App.** Platform iOS. Name "Next
   Caltrain". Primary language English (U.S.). Bundle ID: select
   `com.netpress.NextCaltrain` from the dropdown. SKU: any unique internal
   string (e.g. `nextcaltrain001`).
4. **App Information / age rating**: Apple replaced the old questionnaire in
   January 2026 — ratings are now 4+/9+/13+/16+/18+ (12+ and 17+ no longer
   exist), and the questionnaire itself has new questions covering in-app
   controls, capabilities, medical/wellness topics, and violent themes. Walk
   through it fresh rather than assuming the old "4+" draft in
   `docs/APP_STORE_LISTING.md` still applies as-is — it's the right answer
   for this app's actual content, but confirm via the live questionnaire.
5. **Pricing**: Free.
6. **App Privacy ("nutrition label")**: answer **Data Not Collected** — per
   the notes in `docs/APP_STORE_LISTING.md` (no accounts, analytics, ads, or
   tracking; the only network call is an anonymous fetch of the shared
   `schedule.json`).
7. **Paste in listing copy** from `docs/APP_STORE_LISTING.md`: subtitle,
   description, keywords, promotional text, category (Travel /
   Utilities), privacy policy URL. Upload the app icon and screenshots.

## Step-by-step release procedure (every release)

1. **Bump the version** in `NextCaltrain/Info.plist` (skip the marketing
   version bump for the very first release, which starts at `1.0`/build `1`):
   - `CFBundleVersion` (build number) — **must increase on every single
     upload**, even if the marketing version doesn't change.
   - `CFBundleShortVersionString` (marketing version, e.g. `1.0` → `1.1`) —
     only for an actual user-facing version bump.
2. **Confirm Xcode/SDK**: `xcodebuild -version` — must be Xcode 26+ / iOS 26
   SDK (mandatory since Apr 28, 2026, see Prerequisites).
3. **Regenerate the project**: `./build.sh` runs `xcodegen generate` plus a
   simulator build — good for a quick sanity check, but a simulator build is
   not archivable. Use Xcode for the actual archive (next step).
4. **Archive**: in Xcode, select the **Any iOS Device (arm64)** destination
   (not a simulator) → **Product → Archive**.
5. **Upload**: Xcode → **Window → Organizer → Archives** → select the new
   archive → **Distribute App → App Store Connect → Upload**. (`xcrun
   altool` is deprecated; Organizer or the App Store Connect API are the
   current paths — re-check Apple's tooling at submission time, as this has
   changed before.)
6. **Wait for processing** in App Store Connect (usually a few minutes, can
   run longer) — the build appears under the app's TestFlight/App Store tab
   once ready.
7. App Store Connect → app → version → **Build** → select the uploaded
   build.
8. **TestFlight is optional, not required.** Confirmed: a TestFlight review
   is only triggered if you add *external* testers; internal testing and
   direct-to-review both skip it entirely. This is a real contrast with the
   Android sibling app, which forces a 12-tester/14-day closed-testing gate
   for new developer accounts — iOS has no equivalent gate. Skip TestFlight
   unless you specifically want beta feedback first.
9. **Release notes** ("What's New in This Version") — skip for the very
   first submission, there's nothing prior to describe.
10. **Submit for Review.** Typically 24–48 hours; can run longer for first
    submissions or policy-sensitive content.
11. **Once approved**, choose Manual Release, Automatic Release, or **Phased
    Release** (7-day staged rollout, pausable) — phased release is the
    closest iOS equivalent to a staged rollout.
12. Confirm the listing is live and install from the real App Store on a
    device as a final smoke test.

## Rollback steps

- No built-in "revert to previous binary," same as Android. If a phased
  release is still rolling out, **pause it**: App Store Connect → version →
  Phased Release → Pause.
- If already at 100%, ship a new build with a higher `CFBundleVersion` — not
  a revert.
- "Remove from Sale" exists for an actively harmful release, but it pulls
  the whole listing, not just the bad version — a last resort, not a normal
  rollback tool.

## Escalation / known dead ends

- **Lost signing certificate/private key**: unlike Android's keystore, this
  is recoverable — revoke the old certificate and generate a new one from
  developer.apple.com/account → Certificates, as long as you still have
  access to the Apple Developer account itself. The account, not a local
  file, is the thing that must not be lost.
- **Lost access to the Apple Developer account itself**: this is the iOS
  equivalent of Android's "lost keystore" severity — contact Apple Developer
  Support; recovery is possible but can be slow.
- **Rejected at review**: Resolution Center inside App Store Connect.
  Common first-submission rejections are incomplete metadata, crashes on
  launch, or (not applicable here) missing demo credentials for apps that
  require login.
- The Android sibling app (`next-caltrain-kotlin`) releases to Google Play
  independently — not a blocker for iOS releases.

## References

- `docs/APP_STORE_LISTING.md` — listing copy and privacy/age-rating notes
- `docs/SCREENSHOTS.md` — screenshot capture, sizing, current pics/ status
- `docs/CLAUDE.md` — build/run/test conventions
- `pics/*.png` — existing screenshots (need recapture, see Screenshots step)
