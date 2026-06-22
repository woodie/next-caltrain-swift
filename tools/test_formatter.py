#!/usr/bin/env python3
"""Reformats xcbeautify's flat per-test lines into an indented describe/
context/it tree.

Quick promotes each it() block's full comma-joined description -- every
enclosing describe()/context() plus the it() text itself -- to that test's
XCTest method-selector name (see docs/COWORK.md "Test output formatting" for
why this is a hard limitation of XCTest/Quick, not just a formatter choice).
xcbeautify prints that whole comma-joined string as one flat line per test,
so a spec nested five describe/context levels deep repeats four of them on
every single line. This script un-flattens it: for each test, it splits the
name on ", " and prints only the segments that weren't already printed for
the *previous* test -- the same "dedupe shared prefix" trick the Kotlin
sibling's Gradle TestListener uses (next-caltrain-kotlin/app/build.gradle.kts).

Usage -- insert into the same pipeline slot xcbeautify already occupies:

    xcodebuild test ... | xcbeautify | tools/test_formatter.py

This runs entirely outside the test process, on text xcbeautify already
printed, so it can't interfere with xcodebuild's own stdout capture (the
risk that ruled out the in-process alternatives -- see docs/COWORK.md).

Any line that isn't a recognized pass/skip test result -- build output,
"Test Suite ... started" banners, the final "Executed N tests..." summary,
etc. -- is passed through untouched. Works whether or not xcbeautify's
colored output is enabled: the glyph and the elapsed-time number are the
only parts xcbeautify ever colors, so both are matched (and re-emitted)
including any ANSI codes around them, verbatim.

Failing tests are intentionally NOT torn down into the tree. xcbeautify's
formatFailingTest() joins the failure reason onto the test name with the
same ", " separator the comma-joined name already uses internally, so
there's no recoverable boundary between "name" and "reason" in the text
alone -- unlike pass/skip lines, which have an unambiguous trailing
"(N seconds)". Rather than guess at that boundary and risk mangling a
failure message, a failing line prints verbatim at whatever depth is
currently open, and does NOT update the dedupe state -- so the next passing
test's tree is still computed from the last *known-good* path, not a guess.

Splitting a name on ", " is itself ambiguous whenever a single describe/
context/it string contains a literal ", " of its own -- Quick joins levels
with no escaping, so nothing distinguishes "a comma that separates two
levels" from "a comma that's just part of one level's text". This codebase
hits that in two distinct styles, both confirmed by reading the specs:
parenthetical asides (context("on a weekday (Wednesday, dotw=3)")) and bare
prose (it("is not a transfer, since both endpoints are South County")).
split_path() below only splits at paren-depth 0, which recovers the first
style exactly (the comma never leaves its enclosing parens). The second
style has no such signal -- nothing about "is not a transfer, since both
endpoints are South County" textually distinguishes it from two real
nesting levels, and comparing against neighboring tests doesn't help either
(the ambiguous span doesn't recur anywhere else to confirm or deny against).
It prints as two stacked lines instead of one. This is a real, accepted
limitation of working from xcbeautify's flattened text rather than Quick's
actual ExampleGroup structure -- see docs/COWORK.md "Test output formatting"
for the full writeup and the option (walking ExampleGroup.parent via
@testable import Quick) that would close this gap completely, at the cost
of depending on Quick's internal API.
"""
import re
import sys

PASS, SKIP, FAIL = "✔", "⊘", "✖"  # ✔ ⊘ ✖ -- xcbeautify's TestStatus glyphs

ANSI = r"(?:\x1b\[[0-9;]*m)*"
STRIP_ANSI = re.compile(r"\x1b\[[0-9;]*m")

# A test-result line is Format.indent (4 spaces) + the glyph (maybe
# ANSI-colored) + " " + everything else. Tolerate any leading whitespace
# since this runs after xcbeautify, not on raw xcodebuild output.
GLYPH_RE = re.compile(r"^\s*(" + ANSI + r"[" + PASS + SKIP + FAIL + r"]" + ANSI + r")\s(.*)$")

# Pass/skip lines end in "(<time> seconds)"; the time may itself be
# ANSI-colored (xcbeautify's .coloredTime()).
TIMED_RE = re.compile(r"^(.*) \((" + ANSI + r"[\d.]+" + ANSI + r") seconds\)$")

# xcodebuild/xcbeautify announce every suite -- wrapper ('All tests',
# '<scheme>Tests.xctest') and real spec alike -- with one of these two line
# shapes. A blank line is printed before every single one of them,
# unconditionally, so each suite's announcement visually stands apart from
# whatever came before it (the previous suite's tree + its own
# "Executed N tests..." summary, another suite's banner, or build output).
SUITE_STARTED_RE = re.compile(r"^Test Suite '.*' started at ")
SUITE_FINISHED_RE = re.compile(r"^Test Suite '.*' (?:passed|failed) at ")

INDENT = "  "


def split_path(name: str) -> list[str]:
    """Split a Quick-flattened comma-joined test name back into its
    describe/context/it segments.

    Only splits on ", " when parenthesis depth is 0, so a parenthetical
    aside's internal comma (e.g. "on a weekday (Wednesday, dotw=3)") is
    never mistaken for a level boundary. See the module docstring for what
    this does and doesn't catch.
    """
    parts = []
    current: list[str] = []
    depth = 0
    i = 0
    n = len(name)
    while i < n:
        ch = name[i]
        if ch == "(":
            depth += 1
            current.append(ch)
            i += 1
        elif ch == ")":
            depth = max(depth - 1, 0)
            current.append(ch)
            i += 1
        elif depth == 0 and name[i:i + 2] == ", ":
            parts.append("".join(current))
            current = []
            i += 2
        else:
            current.append(ch)
            i += 1
    parts.append("".join(current))
    return parts


def main() -> None:
    last_path: list[str] = []
    seen_any_line = False

    for raw_line in sys.stdin:
        line = raw_line.rstrip("\n")

        if seen_any_line and (SUITE_STARTED_RE.match(line) or SUITE_FINISHED_RE.match(line)):
            print(flush=True)
        seen_any_line = True

        m = GLYPH_RE.match(line)
        if not m:
            print(line, flush=True)
            continue

        glyph_token, rest = m.group(1), m.group(2)
        bare_glyph = STRIP_ANSI.sub("", glyph_token)

        if bare_glyph == FAIL:
            # No recoverable name/reason boundary -- see module docstring.
            # Print as a sibling of the last known leaf (same depth, not one
            # deeper) and don't touch last_path -- the next pass/skip test's
            # tree is still computed from the last *known-good* path.
            depth = max(len(last_path) - 1, 0)
            print(INDENT * depth + glyph_token + " " + rest, flush=True)
            continue

        if bare_glyph not in (PASS, SKIP):
            print(line, flush=True)
            continue

        timed = TIMED_RE.match(rest)
        if not timed:
            # Doesn't match the shape we know how to split; don't risk mangling it.
            print(line, flush=True)
            continue

        name, time_token = timed.group(1), timed.group(2)
        path = split_path(name)

        shared = 0
        for a, b in zip(path, last_path):
            if a != b:
                break
            shared += 1

        for depth in range(shared, len(path) - 1):
            print(INDENT * depth + path[depth], flush=True)

        leaf_depth = len(path) - 1
        print(
            INDENT * leaf_depth + glyph_token + " " + path[-1] + " (" + time_token + " seconds)",
            flush=True,
        )
        last_path = path


if __name__ == "__main__":
    main()
