# Next Caltrain iOS: video script and publishing steps

Oct 20, 2026 · John Woodell

## Review of Apple's letter

Apple didn't find a defect: it's a Guideline 2.1 "Information Needed" hold, so one reply with a screen recording and seven answers should clear it, with no new build. `letter.md` is the generic "Changes needed" notice, and it says so directly: when Apple only needs information, you make the changes and send a message from the App Review page, without resubmitting. `review.md` lists exactly what that message needs.

The app has none of the special flows Apple asks to see in the recording: no accounts, no purchases, no user content, and no permission prompts (no location, contacts, camera or tracking). Say that outright in the reply, so the reviewer doesn't go looking for them.

| # | Apple asks for | What to answer |
| --- | --- | --- |
| 1 | A screen recording on a physical device with the latest iOS, starting at launch | Record on your iPhone (see the script below). State that there's no login, purchase, user content or permission prompt to show. |
| 2 | Devices and iOS versions tested | Open question: list the physical iPhone(s) and iOS versions you tested on. The app supports iPhone only, iOS 17 and later; add the simulators you used, such as iPhone 17 Pro Max on iOS 26.5. |
| 3 | Purpose and target audience | A Caltrain schedule for riders on the San Francisco Peninsula: a live countdown to the next train between your two stations, with weekday, weekend and holiday schedules picked automatically, including Local, Limited, Express and South County service. |
| 4 | Setup and how to reach the main features | No login or setup. On first launch it shows trips between default stations; tap a trip for its stop-by-stop schedule, and change stations from the station picker. |
| 5 | External services | One: the schedule file at next-caltrain-pwa.appspot.com (Google App Engine), which you build from Caltrain's public GTFS feed. No authentication, payments, analytics, ads or AI services. |
| 6 | Regional differences | None: the app works the same everywhere. Its content is Caltrain's schedule (San Francisco Bay Area), and times follow the phone's own time zone, which is meant for riders in that area. |
| 7 | Regulated industry or third-party material | Not regulated. The schedule comes from Caltrain's openly published GTFS feed; link Caltrain's developer or data-use page if you have it. |

After Apple replies, paste the same answers into the Notes field of App Review Information, as `review.md` asks, so the next submission carries them.

## Video script

One take of about 90 seconds, starting on the iPhone Home Screen, covers every core feature. Apple doesn't need narration; the captions column is optional text you can add when trimming, or skip.

| Time | On screen | Optional caption |
| --- | --- | --- |
| 0:00 | iPhone Home Screen, then tap the Next Caltrain icon | Launching Next Caltrain |
| 0:05 | Home screen: the next train between the default stations, with its countdown ticking | Live countdown to the next train |
| 0:15 | Drag left and right on the trip to step through later trains, then back | Later trains |
| 0:25 | Tap the trip to open the trip list for the day | Today's trains between your stations |
| 0:35 | Tap the schedule label to cycle Weekday, Weekend and Holiday, ending back on today's | Weekday, weekend and holiday schedules |
| 0:45 | Tap a train to open its stop-by-stop schedule, then go back | Every stop for that train |
| 0:55 | Tap the stations to open station selection; pick San Francisco and Gilroy, then Save and confirm "Stations Defaults" | Choosing your stations |
| 1:10 | Back on the trip list, tap a San Francisco to Gilroy weekday train to show the San Jose Diridon transfer | South County trips with a transfer |
| 1:20 | Go back to Home and tap the "Next Caltrain" title to open About, which names the schedule's data source | About and data source |
| 1:30 | Swipe up to the Home Screen to end |  |

Before recording, set the stations back to your usual pair so the first screen looks like a normal day. Record on a weekday so the South County transfer at 1:10 has trains to show.

## Steps to publish

The build stays as submitted: record, reply once in App Store Connect, then wait for App Review, typically within 48 hours.

1. **Prepare the iPhone.** Update it to the latest iOS in Settings > General > Software Update, install the build under review from TestFlight, and turn on Do Not Disturb so no notifications appear.
2. **Add Screen Recording** to Control Center if it isn't there: open Control Center, tap +, then Add a Control > Screen Recording.
3. **Record** following the script: start the recording from Control Center on the Home Screen, perform each step, then stop it. It saves to Photos.
4. **Trim** the start and end in Photos (Edit) so the video opens on the Home Screen and ends after About. Keep it under about two minutes.
5. **Move it to the Mac** with AirDrop, and watch it through once at full size.
6. **Write the reply** from the answers in the review table above: fill in item 2 with your real devices, and say plainly that there's no login, purchase, user content or permission prompt.
7. **Send it** in App Store Connect: Apps > Next Caltrain > App Review, open the message about this submission, paste the answers, attach the video and send. If the attachment is too large, upload it as an unlisted video and put the link in the reply instead.
8. **Don't resubmit the build.** Apple's letter says a reply is enough when only information is needed; resubmitting would restart the review queue.
9. **Copy the answers** into App Review Information > Notes for this version, so the next submission includes them.
10. **Wait for App Review.** Answer any follow-up the same way; once approved, release the version as planned in [RELEASE.md](RELEASE.md).
