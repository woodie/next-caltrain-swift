# Testing the Schedule Loading/Error States

This walks through verifying all startup loading/error behaviors for the
schedule fetch.

## Behavior summary

| # | Cache | Network | Expected result |
|---|-------|---------|------------------|
| 1 | none | fails | Loading screen stays, "Unable to load schedule" |
| 2 | none | succeeds | Loading screen briefly, then Home (fresh data) |
| 3 | valid | succeeds | Home almost instantly (cache), background refresh updates cache |
| 4 | valid | fails (instant) | "Loading schedule data" briefly, then Home (cached data) |
| 5 | valid | hangs >10s | "Loading schedule data" for ~10s, then Home (cached data) |
| 6 | corrupted/invalid | (either) | Treated as case 1 or 2 — `loadCached()` returns nil, falls through |

Cases 1, 2, and 6 represent "fresh install" or "cache lost" scenarios.
Cases 3–5 represent "returning user" scenarios. 5 is the only one exercising
the actual 10-second timeout race; the others are either instant
success/failure.

## Tools needed

- **Real endpoint**: `https://next-caltrain-pwa.appspot.com/feed/schedule.json`
  (the normal `remoteURL`)
- **Instant-failure endpoint**: `http://127.0.0.1:9/schedule.json` (nothing
  listens on port 9 → connection refused immediately)
- **Hanging endpoint**: a local server that accepts the connection but never
  responds, for case 5:
  ```
  python3 -c "import http.server,time,socketserver
  class H(http.server.BaseHTTPRequestHandler):
      def do_GET(self):
          time.sleep(30)
  socketserver.TCPServer(('127.0.0.1',8123),H).serve_forever()"
  ```
  Run this in its own terminal, leave it running, Ctrl-C when done. Use
  `http://127.0.0.1:8123/schedule.json` as `remoteURL` for case 5.

All three are set via `SCHEDULE_URL` in `local.env` (gitignored — this is the
per-developer test override; don't confuse it with the committed
`schedule-endpoint.env`, which holds the real production URL. `sim.sh run` sources
both, `local.env` taking precedence, and passes the result to the simulator as
`SIMCTL_CHILD_SCHEDULE_URL` — see `docs/CLAUDE.md`):

```
SCHEDULE_URL=<ENDPOINT HERE>
```

Switching endpoints is just an edit to `local.env` + `./sim.sh run` — no rebuild needed,
since it's read at runtime via `ProcessInfo`. `./build.sh` only needs to run once per
session (or after actual source changes).

**Always leave `SCHEDULE_URL` commented out (or absent) when you're done testing.**

## Cache helper commands

By default `./sim.sh run` preserves app data across runs (just forces a cold
relaunch via `simctl terminate`) — use `./sim.sh run --fresh` (or `-f`) for a full
wipe (uninstall) when you need to guarantee no cache at all.

Delete cache only (forces "no cache" state without touching other app data):
```
find ~/Library/Developer/CoreSimulator/Devices -path "*Containers/Data/Application/*/Documents/schedule.json" -delete
```

Check whether cache exists:
```
find ~/Library/Developer/CoreSimulator/Devices -path "*Containers/Data/Application/*/Documents/schedule.json"
```

Corrupt the cache (for case 6) — after locating the path with the command
above, overwrite it with garbage:
```
echo '{not valid json' > <path-from-above>
```

Reset the "fetched today" flag (cache stays, but the next launch races a
fresh fetch instead of taking the instant cache-only path) — needed before
cases 4 and 5, since a prior successful/attempted fetch in the same session
otherwise marks today as already-fetched:
```
xcrun simctl terminate booted com.netpress.NextCaltrain 2>/dev/null
xcrun simctl spawn booted defaults delete com.netpress.NextCaltrain lastFetchTime
```
(Swap `booted` for a specific UDID if you're targeting a non-booted device.)

## Suggested test order

Doing them in this order lets each step set up the next with minimal
endpoint-switching:

Only the first step needs `./build.sh`. After that, switching cases is just
an edit to `local.env` + `./sim.sh run` — the value is read at runtime via
`ProcessInfo`, no rebuild needed.

1. **Case 1 (no cache, fetch fails)**
   - Set `SCHEDULE_URL=http://127.0.0.1:9/schedule.json` in `local.env`
     (simplest; hanging endpoint would also work but takes longer).
   - `./build.sh && ./sim.sh run --fresh` (`--fresh` guarantees no cache).
   - **Expect**: loading screen stays up permanently, "Unable to load
     schedule". No transition to Home.

2. **Case 2 (no cache, real endpoint, success)**
   - Comment out `SCHEDULE_URL` in `local.env` (falls back to the real
     endpoint).
   - `./sim.sh run --fresh`
   - **Expect**: brief loading screen → Home with fresh data. This also
     populates the cache (and marks today as fetched) for the next steps.

3. **Case 3 (valid cache, real endpoint, success)**
   - Cache now exists from step 2. `SCHEDULE_URL` still commented out (real
     endpoint). Plain `./sim.sh run` this time (no `--fresh` — we want to keep
     the cache).
   - **Expect**: near-instant Home (cache hit). Since step 2 already marked
     today as fetched, this takes the cache-only path with no network call
     at all — which is also a valid way to observe that path.

4. **Case 4 (valid cache, instant failure)**
   - Cache still present. Run the "reset fetched-today flag" command above
     (otherwise the cache-only path from step 3 wins again and the fetch
     never happens).
   - Set `SCHEDULE_URL=http://127.0.0.1:9/schedule.json` in `local.env`.
   - `./sim.sh run`
   - **Expect**: "Loading schedule data" flashes briefly, then Home using
     cached data (fetch fails fast, well under 10s).

5. **Case 5 (valid cache, fetch hangs >10s)**
   - Start the hanging Python server in a separate terminal.
   - Cache still present. Run the "reset fetched-today flag" command again
     (step 4's attempt may have marked today as fetched too).
   - Set `SCHEDULE_URL=http://127.0.0.1:8123/schedule.json` in `local.env`.
   - `./sim.sh run`
   - **Expect**: "Loading schedule data" for ~10 seconds, then Home using
     cached data. Time it — should be close to 10s, not instant and not 30s.
   - Stop the Python server (Ctrl-C) when done.

6. **Case 6 (corrupted cache)**
   - Comment out `SCHEDULE_URL` (real endpoint) and `./sim.sh run --fresh` once
     to repopulate a valid cache, then corrupt it using the "Corrupt the
     cache" command above.
   - Set `SCHEDULE_URL=http://127.0.0.1:9/schedule.json` again (to isolate
     cache-validity handling from network success masking it).
   - `./sim.sh run` (no `--fresh` — that would also wipe the corrupted cache
     file we just planted).
   - **Expect**: behaves like case 1 — `loadCached()` rejects the invalid
     JSON, falls through to the no-cache path, fetch fails, "Unable to load
     schedule" stays up.

7. **Final cleanup**
   - Comment out (or delete) `SCHEDULE_URL` in `local.env`. It's gitignored,
     so there's nothing to check into git either way — just leave it unset
     so the next run uses the real endpoint.
   - `./sim.sh run --fresh` once more (clears any garbage cache from step 6) to
     confirm everything's back to normal (case 2 → case 3 on next launch).
   - `git status` should show no changes to tracked files from this testing
     session.
EOF

