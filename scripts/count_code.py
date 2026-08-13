#!/usr/bin/env python3
"""Counts the moon-weblink source and checks the project's line budgets.

The budgets in the project specification refer to *code* lines: lines that are
neither blank nor comments (`//` and `///`). This metric is reported per area:

    core          root *.mbt files that are not tests or generated data
    test          root test_*.mbt files
    cli           cmd/weblink-tool/*.mbt
    examples      examples/**/*.mbt
    total         the sum of the above (generated_relations.mbt is excluded)

Budgets (code lines):

    core       3000 - 4000
    cli+examples 500 - 900
    test       1500 - 2200
    total      5000 - 7500  (hard ceiling 8000)

The script also counts the named `test "..."` blocks, which the specification
requires to be between 100 and 140.

Exit code 0 when every budget is satisfied, 1 otherwise. Intended for CI and
for scripts/verify_all.ps1.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXCLUDED = {"generated_relations.mbt"}

BUDGETS = {
    "core": (3000, 4000),
    "cli_examples": (500, 900),
    "test": (1500, 2200),
    "total": (5000, 7500),
}
HARD_TOTAL_MAX = 8000
TEST_RANGE = (100, 140)


def is_comment(line: str) -> bool:
    return line.lstrip().startswith("//")


def code_line_count(path: Path) -> int:
    count = 0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.strip() and not is_comment(line):
                count += 1
    return count


def gross_line_count(path: Path) -> int:
    with open(path, encoding="utf-8") as fh:
        return sum(1 for _ in fh)


def collect() -> dict:
    core = []
    tests = []
    for f in sorted(ROOT.iterdir()):
        if not f.is_file() or f.suffix != ".mbt" or f.name in EXCLUDED:
            continue
        (tests if f.name.startswith("test_") else core).append(f)
    cli = sorted((ROOT / "cmd" / "weblink-tool").glob("*.mbt"))
    examples = sorted((ROOT / "examples").glob("*/main.mbt"))
    return {"core": core, "test": tests, "cli": cli, "examples": examples}


def count_named_tests(tests: list[Path]) -> int:
    pattern = re.compile(r'^\s*test\s+"')
    total = 0
    for path in tests:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if pattern.match(line):
                    total += 1
    return total


def main() -> int:
    files = collect()

    per_area_code = {
        "core": sum(code_line_count(p) for p in files["core"]),
        "cli": sum(code_line_count(p) for p in files["cli"]),
        "examples": sum(code_line_count(p) for p in files["examples"]),
        "test": sum(code_line_count(p) for p in files["test"]),
    }
    per_area_gross = {
        "core": sum(gross_line_count(p) for p in files["core"]),
        "cli": sum(gross_line_count(p) for p in files["cli"]),
        "examples": sum(gross_line_count(p) for p in files["examples"]),
        "test": sum(gross_line_count(p) for p in files["test"]),
    }

    cli_examples = per_area_code["cli"] + per_area_code["examples"]
    total = sum(per_area_code.values())

    print("code lines per area (blank and comment lines excluded):")
    print(f"  core           {per_area_code['core']:5d}")
    print(f"  cli            {per_area_code['cli']:5d}")
    print(f"  examples       {per_area_code['examples']:5d}")
    print(f"  cli+examples   {cli_examples:5d}")
    print(f"  test           {per_area_code['test']:5d}")
    print(f"  total          {total:5d}")
    print("gross lines including blanks and comments:")
    print(f"  total          {sum(per_area_gross.values()):5d}")

    named_tests = count_named_tests(files["test"])
    print(f"named tests     {named_tests}")

    problems = 0

    def check(label: str, value: int, lo: int, hi: int) -> None:
        nonlocal problems
        if lo <= value <= hi:
            print(f"  OK   {label} {value} in [{lo}, {hi}]")
        else:
            print(f"  FAIL {label} {value} outside [{lo}, {hi}]")
            problems += 1

    check("core", per_area_code["core"], *BUDGETS["core"])
    check("cli+examples", cli_examples, *BUDGETS["cli_examples"])
    check("test", per_area_code["test"], *BUDGETS["test"])
    check("total", total, *BUDGETS["total"])
    if total <= HARD_TOTAL_MAX:
        print(f"  OK   total {total} <= {HARD_TOTAL_MAX}")
    else:
        print(f"  FAIL total {total} exceeds the hard ceiling {HARD_TOTAL_MAX}")
        problems += 1
    check("named tests", named_tests, *TEST_RANGE)

    if problems:
        print(f"{problems} budget(s) out of range.")
        return 1
    print("all line budgets satisfied.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
