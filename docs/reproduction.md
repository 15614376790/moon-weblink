# Reproduction

This document lists the exact commands and recorded outputs needed to
reproduce every number and claim in this project. It is the machine-readable
companion to the process specification.

## Environment

- Windows 11 (build 22621), PowerShell 5.1, Git Bash.
- MoonBit toolchain: `moon 0.1.20260713` (at `D:\Moonbit\bin\moon.exe` in the
  recorded run; any MoonBit build that accepts the same CLI should work).
- Python 3 for the two verifier scripts.
- Working directory: the project root `D:\Moonbit\projects\project9\moon-weblink`.
- Repository: <https://github.com/15614376790/moon-weblink>.

## One-shot verification

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1
```

This runs 25 steps. Recorded outcome on 2026-08-11:

```
ran 25 verification steps
ALL CHECKS PASSED
```

The 25 steps are: `moon fmt --check`; `moon check`/`build`/`test` for each of
`wasm-gc`, `js`, `native` (9 steps); CLI smoke tests (stats, parse,
canonicalize with mixed-case parameter names, validate-malformed, audit-`rev`,
relation lookup, linkset JSON emission — 7 steps); the five examples plus the
header→JSON→header round-trip assertion (6 steps); and the two Python verifiers
(2 steps).

## Formatting

```sh
moon fmt --check        # passes; no formatting drift
```

## Check / build / test across targets

```sh
moon check --target wasm-gc
moon build --target wasm-gc
moon test  --target wasm-gc
moon check --target js
moon build --target js
moon test  --target js
moon check --target native
moon build --target native
moon test  --target native
```

Recorded: all nine commands pass; `moon test` reports **140** tests passing on
each target.

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
  core           3400
  cli             641
  examples        143
  cli+examples    784
  test           1958
  total          6142
gross lines including blanks and comments:
  total          8366
named tests      140
  OK   core 3400 in [3000, 4000]
  OK   cli+examples 784 in [500, 900]
  OK   test 1958 in [1500, 2200]
  OK   total 6142 in [5000, 7500]
  OK   total 6142 <= 8000
  OK   named tests 140 in [100, 140]
all line budgets satisfied.
```

`generated_relations.mbt` is excluded from the budgets.

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

Still **not** done, by the project constraints: `moon login`, `moon publish`,
any `.github/workflows`, Releases, issue/PR templates, any
`repository`/`homepage`/`author` fields in `moon.mod`, any fake GitHub URLs,
and any fabricated copyright holder.
