# Publishing Next Caltrain to the App Store

Working notes for App Store submission. This file is public — keep it free
of secrets (no API keys, no Apple ID credentials, no certificates).

## Status

See the "Prepare for App Store submission" GitHub issue for the current
checklist. High-level remaining items as of this writing:

- Privacy policy page (hosted, linked from App Store Connect)
- App Store listing copy (description, keywords, promotional text)
- Screenshots for the listing (Home, TripList, TripDetail, About/Loading)
- Bundle ID / signing setup for distribution
- Version (`CFBundleShortVersionString`) and build number
  (`CFBundleVersion`) for 1.0
- App Store Connect: app record, privacy questionnaire, age rating,
  category

## App identity

- App name: Next Caltrain
- Bundle ID: `com.netpress.NextCaltrain`
- Differentiators vs. other Caltrain schedule apps: live countdown to next
  train, day-of-week/holiday-aware schedule selection (weekday/weekend/
  modified service via `specialDates`)

## Privacy

The app makes one network request type: fetching `schedule.json` from
`https://next-caltrain-pwa.appspot.com/schedule.json` on launch (and
periodically as a background refresh). No personal data, analytics, or
identifiers are collected or transmitted. Station preferences
(`stopAM`/`stopPM`) are stored locally via `UserDefaults` and never leave
the device.

This should map to "Data Not Collected" in App Store Connect's privacy
questionnaire — but double-check against whatever the actual questionnaire
asks at submission time, since Apple's categories change.

A simple static privacy policy page (e.g. hosted alongside
`next-caltrain-pwa`'s webapp on App Engine, or as a GitHub Pages page from
this repo) should state the above in plain language.

## Listing copy notes

Draft positioning: "Next Caltrain tells you exactly when your next train
leaves — with a live countdown, and it automatically knows whether today's
schedule is weekday, weekend, or a holiday/modified service."

Screenshot candidates (see `docs/*.png` for older reference screenshots —
may want fresh ones from the current build):
- Home view with countdown circle
- Trip list for a route
- Trip detail (stop-by-stop)
- About screen

## Versioning

Check current values in `NextCaltrain.xcodeproj/project.pbxproj`
(`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`) before submission. For a
first release, `1.0` / build `1` is conventional; bump build number for
each subsequent TestFlight/App Store upload even if the marketing version
doesn't change.

## Build & archive

This repo's `build.sh`/`run.sh` are simulator-only (debug builds). App
Store submission requires:

1. An Apple Developer account enrolled in the App Store Connect program.
2. Xcode signing configured for the `com.netpress.NextCaltrain` bundle ID
   (Automatic signing is simplest to start).
3. Archive via Xcode (Product > Archive) on a "Any iOS Device" / generic
   destination — `xcodebuild ... build` for simulator won't produce an
   archivable build.
4. Upload via Xcode Organizer or `xcodebuild -exportArchive` +
   `altool`/`notarytool` equivalents (`xcrun altool` is deprecated; use
   Transporter app or `xcrun notarytool`/App Store Connect API as
   appropriate — verify current Apple tooling at submission time, as this
   changes).

## Open questions for a future session

- Where should the privacy policy be hosted? (GitHub Pages from this repo
  is simplest and free)
- Do we want TestFlight beta testing before public release, or go straight
  to review?
- App icon: confirmed working (train photo, full-bleed). Re-verify it looks
  good as the actual 1024x1024 App Store marketing image too (currently
  generated from the same source via `tools/` — check if a script was
  saved, otherwise regenerate from
  `../next-caltrain-pwa/webapp/icons/android-chrome-512x512.png`).
