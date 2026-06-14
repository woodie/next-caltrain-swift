# Parsing Caltrain Modified Schedule PDFs → CSV

## What you're given

A URL like `https://www.caltrain.com/media/XXXXX` returns a PDF timetable.
Fetching it (e.g. via `web_fetch`) returns extracted text in roughly this
layout, twice — once for "Northbound to SAN FRANCISCO" and once for
"Southbound to SAN JOSE/GILROY":

```
Train No. 101 103 105 107 819 ... 173
Gilroy 6:01a 7:31a
San Martin 6:13a 7:43a
...
San Jose Diridon 4:43a 5:08a 5:58a ... 10:30p 11:30p
...
Menlo Park ... 11:00p 12:00a
Redwood City ... 11:05p 12:05a
...
San Francisco ... 11:16p 11:48p 12:48a
```

The PDF text extraction gives space-separated `time + a/p` tokens per row,
with the row label (station name) first. Sparse rows (stations served by
only a few trains, like Gilroy/San Martin/Morgan Hill/Blossom Hill/Capitol,
or "South County Connector" 8xx trains) have far fewer time tokens than
train-ID columns — **you must align tokens to train IDs by column position
counting from the right or by matching against known train numbers**, since
blank cells aren't represented by any token at all (no placeholder).
`College Park` and `Tamien` rows in modified schedules are often this sparse
too — check the train-ID header row to know how many columns exist, and
which IDs correspond to which token if the row has fewer tokens than the
full train list.

## Output format (matches `tools/convert_schedule.py` / `Schedule.swift`)

Each direction (`modified_north.csv`, `modified_south.csv`) is a CSV where:
- Row 1 = empty cell, then train IDs (e.g. `101,103,105,...,173`)
- Each subsequent row = station name, then one time per train ID column,
  in **`H:MM:00`** format (zero-padded minutes, no AM/PM — see "Minutes
  since midnight" below), or empty if that train doesn't serve that station.
- Row order must match `northStops`/`southStops` from the **weekday**
  CSVs — this is the canonical station list. **Every station in the
  canonical list must have a row in the modified CSV too**, even if it's
  all-empty (see "Broadway" below).

## Time conversion: AM/PM → minutes-since-midnight

The app's `time_to_minutes()` (in `convert_schedule.py`) just does
`hours*60 + minutes` on the raw `H:MM:00` string — **it does NOT look at
AM/PM**. So the CSV's hour value must already encode AM/PM correctly:

- Morning times (`Xa` where X is 1–11, or `12a` = midnight): hour = X
  (or `0`/`24` for 12a, see below).
- Afternoon/evening times (`Xp` where X is 1–11): hour = X + 12.
- Noon (`12p`): hour = 12.
- **Post-midnight rollover** (`12a`–`5a`ish, appearing as the *last* one
  or two columns of a table, after the table has already progressed through
  the evening): these represent times on the *next* day. Encode as
  `24 + X` for `Xa` (e.g. `12:05a` → `24:05:00`, `1:23a` → `25:23:00`),
  **NOT** as `12:XX:00` or `1:XX:00`. This matches the weekday/weekend CSVs'
  convention (e.g. weekday Menlo Park has `...,23:00:00,24:00:00` for trains
  171/173, where 171=11:00p and 173=12:00a).

  **This is the single most common bug.** A naive "strip the a/p" conversion
  will produce `12:05:00` for `12:05a`, which `time_to_minutes` reads as
  *noon* (725 min) instead of *just after midnight* (5 min) — a 12-hour
  error that breaks `Schedule.isValid` (table lengths still match, but
  countdown/sort logic downstream will be wrong) or, if it cascades into
  array-length mismatches from other edits, breaks validation entirely.

  **How to tell if a column is post-midnight vs noon**: look at the
  *trend* across the row. Times should be monotonically increasing (in
  minutes-since-midnight) left to right. If the second-to-last column is
  `11:XXp` (≈23:xx) and the last is `12:XXa`, the last is midnight-rollover
  → `24:XX`. If you instead see `11:XXa` then `12:XXp`, that's just morning
  → noon → both stay as-is (`11:XX` and `12:XX`).

- Similarly, watch for the **reverse** mistake: a genuinely-noon/early-PM
  time (`12:28p`, `1:28p`) being miscoded as `24:28:00`/`25:28:00`. This
  happens if a conversion script assumes "any `12:XX` is midnight" without
  checking AM/PM. Sanity check: northbound train columns in the 130s–140s
  range (early-to-mid afternoon) should have hour values in the 12–17
  range, not 24+.

## Zero-padding

Always write times as `H:MM:00` with **two-digit minutes**: `5:08:00`, not
`5:8:00`. `int("8") == int("08")` so this doesn't break `time_to_minutes`,
but unpadded minutes are a sign the conversion was done with naive string
splitting and is worth double-checking for the AM/PM bugs above. Keep
output padded for readability/diffing even though it's not functionally
required.

## The "Broadway" station (and other zero-service stations)

`Broadway` is a real station in `northStops`/`southStops` (from the weekday
CSVs) that is used by this app specifically to exercise the "NO TRAINS"
empty-state UI — it has genuinely no scheduled service on modified/holiday
schedules (and possibly limited service generally; don't assume).

**The modified-schedule PDF will never mention Broadway** — there's no row
for it in the extracted text. You must still **insert an all-empty
`Broadway,,,,,...,` row** into both `modified_north.csv` and
`modified_south.csv`, at the correct position relative to its neighbors in
the weekday station order:

- North direction order: `...Burlingame, Broadway, Millbrae, San Bruno,
  So San Francisco...`
- South direction order: `...So San Francisco, San Bruno, Millbrae,
  Broadway, Burlingame...`

If you skip this, `Schedule.isValid` will fail (`southModified`/
`northModified` row-length ≠ `southStops`/`northStops` count = 30), and
`Schedule.refreshFromNetwork()` will silently fail to cache the fetched
schedule (logs `[Schedule] fetched schedule failed validation`) — the app
keeps working off the stale bundled/cached copy with no visible error to the
user, so this is easy to miss.

**General rule**: after building each modified CSV, verify its row count
(excluding the header) equals `len(northStops)` / `len(southStops)` from
the weekday CSV, and that station *names* match 1:1 (same set, same order).
Any station present in weekday but absent from the modified PDF needs an
all-empty row inserted in the right spot.

## South County Connector (8xx) trains and sparse columns

Trains like `819`, `825`, `840`, `848` (South County Connector) only run
between South County stations (Gilroy/San Martin/Morgan Hill/Blossom
Hill/Capitol/Tamien) and San Jose Diridon, with timed transfers noted in the
PDF legend (e.g. "6:49a 6:58a Timed transfers for South County service").
These columns will be empty for all Peninsula stations (San Jose Diridon
northward / southward) — make sure the CSV reflects that (empty cells), not
a misalignment that shifts later trains' times into the wrong columns.

`College Park` and `Tamien` (northbound) are similarly sparse — often only
1–2 trains per direction, shown as `–` (en dash, "train bypasses station")
or simply absent from the row's token list for most columns. Map tokens to
columns carefully; counting "this row has N tokens for M columns, so they
must be the Nth-from-last M columns" is usually safer than assuming
left-alignment, since the *first* scheduled train for these stations is
often well into the train list, not train 101/102.

## Recommended workflow for a new modified-schedule PDF

1. Fetch the PDF text via `web_fetch`.
2. Identify the train-ID header row for each direction; count columns.
3. For each station row, map each time token to its train-ID column
   (handle sparse rows per above).
4. Convert each time to `H:MM:00`, applying the AM/PM → hour rules above.
   Pay special attention to the last 1–2 columns of each table (rollover
   risk) and to any `12:XX` values anywhere in the table (noon vs.
   midnight ambiguity).
5. Insert the all-empty `Broadway` row at the correct position for each
   direction.
6. Verify row count and station-name set/order matches `northStops`/
   `southStops` exactly.
7. Run `python3 tools/convert_schedule.py` and check for no errors, then
   spot-check `southModified`/`northModified` lengths via `jq`:
   ```
   jq '.northModified | to_entries | map(.value | length) | unique' assets/schedule.json
   jq '.northStops | length' assets/schedule.json
   ```
   These two numbers must match (and likewise for south).
8. Sanity-check a few known times against the PDF directly (e.g. the first
   and last train of each direction, and anything near a midnight
   rollover) before committing.
