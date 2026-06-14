# Git Workflow & Release Process

## Branching strategy

This project uses a simplified Git Flow model:

- **`main`** — production-ready code, always deployable to App Store. Every
  commit should pass `./test.sh` and be ready for release.
- **Work branches** — all code changes (features, bug fixes, UI polish) happen on
  a branch named after the GitHub issue. Branch from `main`, merge back via
  pull request, then delete the branch.
- **Docs** — documentation updates (`docs/`) commit directly to `main`, no branch needed.

## Branch naming convention

Always tie a branch to a GitHub issue:

```
bugfix/7-no-text-wrap
feature/12-add-gps-location
hotfix/33-fix-crash-on-launch
```

Pattern: `{type}/{issue-number}-{short-description}`

- `bugfix/` — fixes a reported bug (closes a GitHub issue)
- `feature/` — adds new functionality
- `hotfix/` — urgent fix for a production issue

## Feature / bugfix workflow

1. **Create a branch** from `main`, tied to the issue number:
   ```bash
   git checkout main && git pull
   git checkout -b bugfix/7-no-text-wrap
   ```

2. **Make changes** — edit files, run `./build.sh && ./simulate.sh` to
   test interactively, take screenshots for feedback.

3. **Run tests** before committing:
   ```bash
   ./test.sh
   ```
   All tests must pass.

4. **Lint** to catch style issues:
   ```bash
   swiftlint
   ```

5. **Commit** with a message that references the issue:
   ```bash
   git add Sources/TripDetailView.swift
   git commit -m "Fix detail view text wrapping (fixes #7)"
   ```

6. **Push** and open a pull request on GitHub:
   ```bash
   git push -u origin bugfix/7-no-text-wrap
   ```

7. **Merge** via GitHub PR, then clean up:
   ```bash
   git checkout main && git pull
   git branch -d bugfix/7-no-text-wrap
   ```
   (Delete the remote branch via GitHub's "Delete branch" button after merging,
   or with `git push origin --delete bugfix/7-no-text-wrap`.)

## Hotfix workflow (urgent production bugs)

Same as above but use `hotfix/` prefix and merge immediately without waiting
for extended review:

```bash
git checkout main && git pull
git checkout -b hotfix/33-fix-crash-on-launch
# ... fix, test, commit ...
git push -u origin hotfix/33-fix-crash-on-launch
# merge PR immediately, then:
git checkout main && git pull
git branch -d hotfix/33-fix-crash-on-launch
```

After merging a hotfix, **re-release to the App Store** (see below).

## Testing a branch before merging

1. **Unit tests**:
   ```bash
   ./test.sh
   ```

2. **Simulator**:
   ```bash
   ./build.sh && ./simulate.sh
   ```

3. **Edge cases** — if the change touches schedule logic, routing, or time
   calculations, test with debug overrides:
   - Set `GoodTimes.debugOverrideMinutes` / `debugOverrideDotw` to simulate
     different times/days (see `docs/ROLLOVER_NOTES.md`).
   - Test South County no-service behavior (Friday evening → Saturday).
   - Test schedule type cycling (weekday ↔ weekend ↔ modified).

4. **Logs**:
   ```bash
   ./simulate.sh --log
   ```

## Schedule updates (publish new `schedule.json`)

The app fetches `schedule.json` from the network at startup, so updating the
published schedule does **not** require an App Store release.

### Workflow

1. **Update the source CSVs** in `../next-caltrain-pwa/data/`.

2. **Convert to JSON**:
   ```bash
   cd next-caltrain-ios
   python3 tools/convert_schedule.py ../next-caltrain-pwa/data ../next-caltrain-pwa/webapp/schedule.json
   ```

3. **Validate** — the converter prints errors if anything is malformed.

4. **Spot-check** with `jq`:
   ```bash
   jq '.northStops | length' ../next-caltrain-pwa/webapp/schedule.json
   jq '.northWeekday | to_entries | map(.value | length) | unique' ../next-caltrain-pwa/webapp/schedule.json
   ```
   Both values must match (30 stops, all schedule tables have 30 rows).

5. **Commit and deploy**:
   ```bash
   cd ../next-caltrain-pwa
   git add webapp/schedule.json
   git commit -m "Update schedule: new modified schedule for Thanksgiving 2026"
   git push
   npm run deploy
   ```

### Common mistakes to avoid

- Forgetting `convert_schedule.py` — never edit the JSON by hand.
- Bad `12:XX` times (noon vs. midnight) — see `docs/MODIFIED_SCHEDULE_PARSING.md`.
- Missing the all-empty Broadway row in modified schedules.
- Forgetting `npm run deploy` after pushing.

## App Store release workflow

1. **Merge all branches** to `main` and ensure `./test.sh` passes.

2. **Update version numbers** in `NextCaltrain/Info.plist`:
   ```
   CFBundleShortVersionString = 1.1
   CFBundleVersion = 2
   ```

3. **Commit and tag**:
   ```bash
   git add -A
   git commit -m "Release 1.1"
   git tag -a v1.1 -m "Version 1.1 release"
   git push origin main --tags
   ```

4. **Archive and upload** in Xcode:
   - Product > Archive (destination = generic iOS device).
   - Xcode Organizer > Distribute App > App Store Connect.

5. **Submit for review** in App Store Connect and monitor status.

### TestFlight (optional but recommended)

Before App Store review, distribute via TestFlight:
- Xcode Organizer > Distribute App > TestFlight.
- Wait ~10–30 min for Apple to process.
- Invite testers via App Store Connect.

## Regression testing checklist

Before releasing:

- [ ] `./test.sh` passes.
- [ ] `swiftlint` has no errors.
- [ ] `./build.sh && ./simulate.sh` works.
- [ ] Tested on a real device (not just simulator).
- [ ] Schedule loads correctly (check About view).
- [ ] Countdown updates every second; weekday/weekend detection correct.
- [ ] South County Friday evening edge case verified.
- [ ] Dark mode and light mode both look correct.
- [ ] App works offline with a cached schedule.
