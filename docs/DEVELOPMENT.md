# Development

This project assumes macOS with Xcode installed.

## One-time setup

```
brew install xcodegen xcbeautify swiftlint
```

(`brew install` can take a while the first time — these only need to be
installed once.)

## Running tests

Tests are written with [Quick](https://github.com/Quick/Quick) and
[Nimble](https://github.com/Quick/Nimble) in an RSpec-style
`describe`/`context`/`it` format, living in `Tests/`.

```
./test.sh
```

This runs `xcodegen generate` (so newly added spec files are picked up
automatically) and wraps `xcodebuild test`, piped through `xcbeautify`
(falling back to `xcpretty` or a quiet grep if `xcbeautify` isn't
installed) for RSpec `-fd`-style, doc-formatted output: each
`describe`/`context`/`it` shown as a nested line with a pass/fail mark.

First run will resolve and download Quick/Nimble (and their transitive
dependencies) via Swift Package Manager — this requires network access and
may take a minute. Subsequent runs use the cached packages.

The result is at the very end:

```
** TEST SUCCEEDED **
```

or

```
** TEST FAILED **
```

## Linting

```
swiftlint
```

`.swiftlint.yml` relaxes a few rules (`function_body_length`,
`identifier_name`, `static_over_final_class`) that don't fit the Quick spec
DSL — `override class func spec()` and short names like `gt` are
conventional in this style and not worth fighting.

## Regenerating the Xcode project

After adding/removing files or targets, or editing `project.yml`:

```
xcodegen generate
```

`./test.sh` runs this automatically, so new spec files in `Tests/` don't
need a separate step. For the app target (`Sources/`), run it manually
before `./build.sh` if you've added or removed files.

## Simulator build (debug, app target only)

```
./build.sh && ./run.sh
```

`build.sh` wraps `xcodegen` + `xcodebuild ... | grep "error:"` + a clean
simulator reinstall. `run.sh` installs and launches the app.

## Viewing logs

To stream debug logs from the running simulator app:

```
./run.sh --log
```

This captures `os_log` output filtered by tag. To add debug logs in Swift:

```swift
import os.log
os_log("[MyTag] value=%.1f", log: OSLog(subsystem: "com.netpress.NextCaltrain", category: "MyTag"), type: .debug, someValue)
```

The bracketed tag (e.g. `[MyTag]`) must also be added to the predicate in
`run.sh` — look for the `composedMessage CONTAINS` line and add:

```
OR composedMessage CONTAINS "[MyTag]"
```

**Important**: `print()` goes to stdout and is NOT captured by `--log`. Always
use `os_log` with a subsystem for logs you want to see in the terminal.

## Quick reference

| Task | Command |
| --- | --- |
| One-time setup | `brew install xcodegen xcbeautify swiftlint` |
| Regenerate Xcode project | `xcodegen generate` |
| Run unit tests | `./test.sh` |
| Lint | `swiftlint` |
| Build + run in simulator | `./build.sh && ./run.sh` |
| View debug logs | `./run.sh --log` |
