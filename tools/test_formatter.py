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
hits that in two distinct styles: parenthetical asides
(context("on a weekday (Wednesday, dotw=3)")) and bare prose
(it("is not a transfer, since both endpoints are South County")).

_split_path_heuristic() below only splits at paren-depth 0, which recovers
the parenthetical style exactly (the comma never leaves its enclosing
parens) but not bare prose -- nothing about "is not a transfer, since both
endpoints are South County" textually distinguishes it from two real
nesting levels.

split_path() resolves the bare-prose case differently: it reads every
describe/context/it string literal directly out of Tests/*.swift (see
load_known_atoms()) and treats that set as a dictionary, then looks for a
way to break the flattened name into a sequence of dictionary entries
joined by ", ". Because the dictionary comes from the exact same source
that produced the name, the correct decomposition always exists; a bare
prose comma simply fails to produce any *other* valid decomposition (the
text on either side of it isn't itself a known describe/context/it string),
so the full it() text matches as a single atom. See
_find_decompositions()'s docstring for why this only needs to distinguish
"exactly one decomposition" from "zero or more than one", not enumerate
every possibility.

This still isn't a complete substitute for Quick's actual ExampleGroup
structure (see docs/COWORK.md "Test output formatting" for that option, and
why it's a bigger, riskier change): it depends on Tests/ being readable
next to this script, doesn't follow `\(...)` string interpolation in a
description (those atoms just never match anything, so they're harmless
but useless), and -- in the genuinely ambiguous case where a name can be
decomposed two different valid ways -- falls back to the old paren-depth-0
heuristic rather than guessing. That fallback is the same one this script
always used, so behavior degrades to the previous (known) limitation rather
than to something worse.
"""
import re
import sys
from pathlib import Path

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

# Tests/*.swift lives one directory up from tools/test_formatter.py.
TESTS_DIR = Path(__file__).resolve().parent.parent / "Tests"

# Matches the literal-string argument of a describe/context/it call, e.g.
# describe("TripViewModel") or it("is not a transfer, since both endpoints
# are South County"). Captures the raw (still-escaped) literal text between
# the quotes; doesn't require the call to close on the same line.
ATOM_CALL_RE = re.compile(r'\b(?:describe|context|it)\(\s*"((?:[^"\\]|\\.)*)"')


def _unescape_swift_literal(raw: str) -> str:
    """Undo Swift string-literal escapes (\\", \\\\, \\n, \\t, ...) so the
    dictionary holds the same text Quick actually renders at runtime."""
    out: list[str] = []
    i = 0
    n = len(raw)
    while i < n:
        ch = raw[i]
        if ch == "\\" and i + 1 < n:
            nxt = raw[i + 1]
            out.append({"n": "\n", "t": "\t"}.get(nxt, nxt))
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def load_known_atoms(tests_dir: Path) -> frozenset[str]:
    """Collect every describe/context/it literal string used anywhere under
    tests_dir. Returns an empty set (never raises) if the directory isn't
    there or isn't readable -- callers treat an empty dictionary as "can't
    disambiguate" and fall back to the paren-depth-0 heuristic, the same
    behavior this script always had.

    Doesn't follow string interpolation (`\\(...)`) -- a description built
    that way isn't a static literal, so it can't be precomputed here. Such
    an atom is simply captured verbatim (backslash, parens, and all) and
    will never match real xcbeautify output, which is harmless: it's a dead
    dictionary entry, not a wrong one.
    """
    atoms: set[str] = set()
    try:
        paths = sorted(tests_dir.glob("*.swift"))
    except OSError:
        return frozenset()
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        for m in ATOM_CALL_RE.finditer(text):
            atoms.add(_unescape_swift_literal(m.group(1)))
    return frozenset(atoms)


KNOWN_ATOMS = load_known_atoms(TESTS_DIR)


def _find_decompositions(name: str, atoms: frozenset[str], limit: int = 2) -> list[list[str]]:
    """Try to split `name` into a sequence of dictionary entries joined by
    ", ", stopping once `limit` distinct decompositions have been found.

    Callers only need to tell "exactly one" apart from "zero, or more than
    one" -- a unique decomposition is trustworthy, anything else isn't --
    so there's no reason to enumerate every possibility once a second one
    has shown up. Atoms are tried longest-first at each position purely as
    a fail-fast ordering; it doesn't change which decompositions exist.
    """
    if not atoms:
        return []
    by_length_desc = sorted(atoms, key=len, reverse=True)
    results: list[list[str]] = []
    n = len(name)

    def rec(start: int, path: list[str]) -> None:
        if len(results) >= limit:
            return
        if start == n:
            results.append(list(path))
            return
        for atom in by_length_desc:
            if len(results) >= limit:
                return
            if not atom or not name.startswith(atom, start):
                continue
            end = start + len(atom)
            if end == n:
                path.append(atom)
                rec(end, path)
                path.pop()
            elif name.startswith(", ", end):
                path.append(atom)
                rec(end + 2, path)
                path.pop()

    rec(0, [])
    return results


def _split_path_heuristic(name: str) -> list[str]:
    """Split a Quick-flattened comma-joined test name back into its
    describe/context/it segments using parenthesis depth alone.

    Only splits on ", " when parenthesis depth is 0, so a parenthetical
    aside's internal comma (e.g. "on a weekday (Wednesday, dotw=3)") is
    never mistaken for a level boundary. This is the fallback split_path()
    uses when the Tests/*.swift dictionary can't uniquely resolve a name --
    see the module docstring for what it does and doesn't catch.
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


def split_path(name: str) -> list[str]:
    """Split a Quick-flattened comma-joined test name back into its
    describe/context/it segments.

    Tries the Tests/*.swift dictionary first (see module docstring); falls
    back to the paren-depth-0 heuristic when that can't find exactly one
    decomposition.
    """
    dict_splits = _find_decompositions(name, KNOWN_ATOMS)
    if len(dict_splits) == 1:
        return dict_splits[0]
    return _split_path_heuristic(name)


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
            print(INDENT * (depth + 1) + glyph_token + " " + rest, flush=True)
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
            print(INDENT * (depth + 1) + path[depth], flush=True)

        leaf_depth = len(path) - 1
        print(
            INDENT * (leaf_depth + 1) + glyph_token + " " + path[-1] + " (" + time_token + " seconds)",
            flush=True,
        )
        last_path = path


if __name__ == "__main__":
    main()
