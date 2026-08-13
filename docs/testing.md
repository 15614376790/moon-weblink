# Testing

This document describes how `moon-weblink` is tested and how to reproduce the
numbers in the [README](../README.md).

## Test architecture

All tests live in root `test_*.mbt` files and run under `moon test` for each of
the three targets (`wasm-gc`, `js`, `native`). There are no external test
frameworks, no mock servers and no network access: the suite is deterministic
and self-contained.

The suite is organized by concern:

| File | Covers |
| --- | --- |
| `test_parser.mbt` | RFC 8288 link-value parsing, parameters, case-insensitivity |
| `test_serializer.mbt` | serialization and canonicalization |
| `test_rfc8187.mbt` | extended parameter values, decode + encode |
| `test_uri_ref.mbt` | RFC 3986 parsing and resolution |
| `test_linkset_text.mbt` | application/linkset text format |
| `test_linkset_json.mbt` | application/linkset+json format |
| `test_conversion.mbt` | header ↔ text ↔ json conversions |
| `test_model.mbt` | model invariants and duplicate handling |
| `test_query.mbt` | find/filter helpers, relation membership |
| `test_relation.mbt` | relation helpers over the registry |
| `test_registry.mbt` | the offline IANA registry itself |
| `test_audit.mbt` | the deterministic audit |
| `test_limits.mbt` | resource-limit presets and enforcement |
| `test_invalid.mbt` | malformed inputs → structured errors |
| `test_truncation.mbt` | every byte-prefix never panics |
| `test_property.mbt` | randomized-but-deterministic property cases |
| `test_helpers.mbt` | shared test utilities (no tests of their own) |

## Named tests

The library suite has **140 named `test "..."` blocks**, satisfying the
process specification's range of 100–140 as counted by `scripts/count_code.py`
over the root `test_*.mbt` files. The CLI package adds **7 whitebox tests**
(`cmd/weblink-tool/cli_wbtest.mbt`) covering argv normalization across
targets, so `moon test` runs **147** named tests in total. Each block asserts
specific behavior; a failure names the exact property under test.

## Property cases (deterministic)

`test_property.mbt` generates **1200 property cases** over constructed link
collections. Determinism is guaranteed three ways:

- **No `random`/`time`.** The corpus is generated from fixed seeds in code
  (seeded, reproducible arithmetic), so the exact same 1200 cases run on every
  invocation and every target.
- **No wall-clock dependence.** There is no timing logic anywhere in the
  suite.
- **Fixed iteration order.** The generated collections are ordered by
  construction, not by a hash, so the assertion order is stable.

The property checks assert the round-trip and normalization invariants: parse
→ serialize → parse is a fixed point, canonicalization is idempotent, linkset
conversions are semantics-preserving at the model boundary for the supported
scope, and the audit is order-stable.

## Truncation cases

`test_truncation.mbt` applies the **truncation safety** rule to a corpus of
complex inputs: for each input, **every byte-prefix** (including the empty
prefix and the full input) is fed to the parser. There are **2504 such cases**,
and the invariant is that no prefix ever panics — every prefix returns either
`Ok` or a structured `Err`. This is the project's strongest no-panic guarantee,
complemented by `test_invalid.mbt`'s malformed-input cases.

## Malformed input

`test_invalid.mbt` feeds a broad set of malformed values (unterminated quoted
strings, stray commas, invalid percent escapes, empty relation sets, bad
ext-values, malformed JSON and text linksets, out-of-limits payloads) and
asserts that each one yields a `LinkError` with a stable `(stage, kind)` pair
and a sane byte offset — never a panic and never a partial success.

## Targets

Every test compiles and runs identically on all three targets:

```sh
moon check --target wasm-gc
moon check --target js
moon check --target native
moon test  --target wasm-gc
moon test  --target js
moon test  --target native
```

The targets share the same `.mbt` source and the same assertions; the suite
contains no backend-specific code.

## Verification entry points

- `powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1` — runs the
  34-step end-to-end check (format, three targets, per-target CLI smoke,
  CLI content assertions, examples, budgets, IANA snapshot).
- `python scripts/count_code.py` — prints code-line counts per area and
  verifies the line budgets and the 140-test library count.
- `python scripts/verify_iana_snapshot.py` — verifies the offline IANA snapshot
  integrity (sha256, record count, generated-file staleness).

See [reproduction.md](reproduction.md) for the exact commands and expected
outputs.
