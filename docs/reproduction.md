# Reproduction

This document lists the exact commands and recorded outputs needed to
reproduce every number and claim in this project. It is the machine-readable
companion to the process specification.

## Environment

- Windows 11 (build 22621), PowerShell 5.1, Git Bash.
- MoonBit toolchain: `moon 0.1.20260819` (at `D:\Moonbit\bin\moon.exe` in the
  recorded run; a compatible newer toolchain should also work).
- Python 3 for the two verifier scripts.
- Working directory: the project root `D:\Moonbit\projects\project9\moon-weblink`.
- Repository: <https://github.com/15614376790/moon-weblink>.

## One-shot verification

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1
```

This runs 43 steps. Recorded outcome on 2026-08-21:

```
ran 43 verification steps
ALL CHECKS PASSED
```

The 43 steps are: `moon fmt --check`; `moon info`; strict
`moon check`/`build`/`test` for `wasm`, `wasm-gc`, `js`, `native` (12 steps);
core CLI smoke tests (version, parse, canonicalize with mixed-case parameter
names, relation lookup) on each target (16 steps); CLI content assertions
(stats, validate-malformed, audit-`rev`, linkset JSON emission — 4 steps);
the five examples plus the header→JSON→header round-trip assertion (6 steps);
the two Python verifiers (2 steps); and `moon package --list`.

## Formatting

```sh
moon fmt --check        # passes; no formatting drift
```

## Check / build / test across targets

```sh
moon check --target wasm --deny-warn
moon build --target wasm
moon test  --target wasm --deny-warn
moon check --target wasm-gc --deny-warn
moon build --target wasm-gc
moon test  --target wasm-gc --deny-warn
moon check --target js --deny-warn
moon build --target js
moon test  --target js --deny-warn
moon check --target native --deny-warn
moon build --target native
moon test  --target native --deny-warn
```

Recorded: all twelve commands pass; `moon test` reports **147** tests passing on
each target (140 library blackbox tests + 7 CLI whitebox tests).

## CLI smoke tests

```sh
moon run cmd/weblink-tool -- stats
moon run cmd/weblink-tool -- parse --input '<https://a.example/>; rel="next"'
moon run cmd/weblink-tool -- canonicalize --input '<https://a.example/>; REL="canonical"'
moon run cmd/weblink-tool -- validate --input 'not a link'
moon run cmd/weblink-tool -- audit --input '<https://a.example/>; rel="canonical"; rev="made"'
moon run cmd/weblink-tool -- relation next
moon run cmd/weblink-tool -- to-linkset-json --input '<a>; rel=next'
```

The core smoke tests (version, parse, canonicalize, relation) also run once
per target in the verification gate, using the toolchain's `--target` flag:

```sh
moon run --target wasm    cmd/weblink-tool -- version
moon run --target wasm-gc cmd/weblink-tool -- version
moon run --target js      cmd/weblink-tool -- parse --input '<https://a.example/>; rel="next"'
moon run --target native  cmd/weblink-tool -- canonicalize --input '<https://a.example/>; REL="canonical"'
```

Recorded behaviors: the canonicalize step prints
`<https://a.example/>; rel="canonical"` (uppercase `REL` folded to lowercase —
RFC 5234 case-insensitivity); `validate` on `not a link` prints
`valid: false`; `audit` on the `rev` sample prints a `deprecated-rev` finding;
`relation next` prints the `next` registry entry; `to-linkset-json` emits a
document containing `"linkset"` and the `"next"` member.

> Note for Windows PowerShell 5.1: embedded double quotes cannot pass through
> a native-command argument (CommandLineToArgvW mangling), so the CLI JSON
> smoke test keeps its argv quote-free. The full header↔JSON↔header round-trip
> is exercised in-process by the `linkset_json` example and by the test suite.

## Examples

```sh
moon run examples/parse_header
moon run examples/pagination
moon run examples/linkset_json
moon run examples/relation_query
moon run examples/audit_header
```

Recorded: all five run without error; `linkset_json` prints a linkset JSON
document and then converts back to a Link header that still contains
`rel="stylesheet"`.

## Line budgets and named-test count

```sh
python scripts/count_code.py
```

Recorded output (code lines = non-blank, non-comment):

```
code lines per area (blank and comment lines excluded):
  core           3403
  cli             729
  examples        143
  cli+examples    872
  test           1958
  total          6233
gross lines including blanks and comments:
  total          8505
named tests      140
  OK   core 3403 in [3000, 4000]
  OK   cli+examples 872 in [500, 900]
  OK   test 1958 in [1500, 2200]
  OK   total 6233 in [5000, 7500]
  OK   total 6233 <= 8000
  OK   named tests 140 in [100, 140]
all line budgets satisfied.
```

`generated_relations.mbt` is excluded from the budgets. The 140 named tests
counted above are the library blackbox tests; `moon test` additionally runs
the 7 CLI whitebox tests (`cmd/weblink-tool/cli_wbtest.mbt`), for 147 in
total.

## IANA snapshot integrity

```sh
python scripts/verify_iana_snapshot.py
```

Recorded output:

```
OK   sha256 37109cf6ccf9e4e5e035e8ca1d2fb9f41f5972f7656c033f07e9c58a66769dd4
OK   record_count 134
OK   generated_relations.mbt is current
IANA snapshot OK.
```

The snapshot is pinned in `testdata/iana/link-relations.csv` (134 records,
retrieved 2026-08-11 from the IANA Link Relation Types registry; the retrieval
metadata lives in `testdata/iana/SOURCE.json`).

## Property and truncation corpora

- **1200 deterministic property cases** in `test_property.mbt`, generated from
  fixed seeds with no `random`/`time` dependence; counted by the test body.
- **2504 truncation cases** in `test_truncation.mbt`: every byte-prefix of each
  complex input is parsed and must never panic.

Both numbers are stable across runs and targets and are asserted by the test
suite itself (a mismatch fails the build).

## Version control and publishing status

The project was originally delivered as a complete local directory. At the
maintainer's request it is now versioned with git and published to GitHub
under the maintainer's own account (`15614376790`), at
<https://github.com/15614376790/moon-weblink>; commits are authored with the
maintainer's real identity, configured by them in their git config.

Version `0.1.0` was published to Mooncakes on 2026-08-13. The final-acceptance
release is version `0.1.1`, published under the same package name at
<https://mooncakes.io/package/15614376790/moon-weblink> after the local and
GitHub Actions gates pass.

The repository now includes `.github/workflows/ci.yml`, which repeats the
strict four-target build and test checks on pushes and pull requests. No
fabricated author metadata or unrelated release assets are added.
