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

- **Real endpoint**: `https://next-caltrain-pwa.appspot.com/schedule.json`
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

All three are set via the same edit point in `Sources/CaltrainSchedule.swift`:

```swift
private static let remoteURL = URL(string: "<ENDPOINT HERE>")!
```

**Always revert to the real endpoint when you're done testing.**

## Cache helper commands

Delete cache (forces "no cache" state):
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

## Suggested test order

Doing them in this order lets each step set up the next with minimal
endpoint-switching:

1. **Case 1 (no cache, fetch fails)**
   - Delete cache.
   - `remoteURL` = port-9 instant-failure endpoint (simplest; hanging
     endpoint would also work but takes longer).
   - `./build.sh && ./run.sh`
   - **Expect**: loading screen stays up permanently, "Unable to load
     schedule". No transition to Home.

2. **Case 2 (no cache, real endpoint, success)**
   - Delete cache.
   - `remoteURL` = real endpoint.
   - `./build.sh && ./run.sh`
   - **Expect**: brief loading screen → Home with fresh data. This also
     populates the cache for the next steps.

3. **Case 3 (valid cache, real endpoint, success)**
   - Cache now exists from step 1. `remoteURL` still real.
   - `./build.sh && ./run.sh`
   - **Expect**: near-instant Home (cache hit), background refresh
     succeeds silently.

4. **Case 4 (valid cache, instant failure)**
   - Cache still present. Switch `remoteURL` to the port-9 instant-failure
     endpoint.
   - `./build.sh && ./run.sh`
   - **Expect**: "Loading schedule data" flashes briefly, then Home using
     cached data (fetch fails fast, well under 10s).

5. **Case 5 (valid cache, fetch hangs >10s)**
   - Start the hanging Python server in a separate terminal.
   - Cache still present. Switch `remoteURL` to the hanging endpoint
     (`http://127.0.0.1:8123/schedule.json`).
   - `./build.sh && ./run.sh`
   - **Expect**: "Loading schedule data" for ~10 seconds, then Home using
     cached data. Time it — should be close to 10s, not instant and not 30s.
   - Stop the Python server (Ctrl-C) when done.

6. **Case 6 (corrupted cache)**
   - Run with the real endpoint once to repopulate a valid cache (same as
     step 1), then corrupt it using the "Corrupt the cache" command above.
   - Switch `remoteURL` to the port-9 instant-failure endpoint (to isolate
     cache-validity handling from network success masking it).
   - `./build.sh && ./run.sh`
   - **Expect**: behaves like case 1 — `loadCached()` rejects the invalid
     JSON, falls through to the no-cache path, fetch fails, "Unable to load
     schedule" stays up.

7. **Final cleanup**
   - Set `remoteURL` back to the real endpoint:
     ```swift
     private static let remoteURL = URL(string: "https://next-caltrain-pwa.appspot.com/schedule.json")!
     ```
   - Delete cache (it may contain garbage from step 6) and run once more to
     confirm everything's back to normal (case 2 → case 3 on next launch).
   - `git diff Sources/CaltrainSchedule.swift` should show no changes before
     committing other work.
EOF

