# Contributing

Thanks for considering a contribution to `moon-weblink`. This document covers
the ground rules, the verification gate, and the conventions used in this
repository.

## Project status and scope

`moon-weblink` is a MoonBit library project, versioned with git and hosted on
GitHub (see the repository link in the [README](README.md)). It has no CI
configuration and no Releases; contributions happen as pull requests or file
changes in this working tree. The scope is fixed by the project
specification: a strict RFC 8288 / RFC 9264 toolkit with the module name
`15614376790/moon-weblink` at version `0.1.0`. Keep the scope — a change that
pulls in a large new dependency or a full HTTP client is out of scope.

## Ground rules

1. **No Mooncakes publishing.** Do not run `moon login` or `moon publish`.
   Git is the normal development workflow (commit, push, pull request); the
   project has no CI configuration or Releases, so do not add them without
   the maintainer's approval.
2. **No fabricated identity.** Do not invent author names, emails, phones,
   schools, companies, orgs, GitHub usernames or Mooncakes usernames in any
   file, and do not add `homepage`/`author`/`maintainer`/`email` to
   `moon.mod` (the only repository-metadata field present is `repository`,
   pointing at the real GitHub repository). Commit identity is each
   contributor's own, configured in their own git config.
3. **No fake metadata.** Do not add fake GitHub URLs or a fabricated copyright
   holder. The LICENSE is Apache-2.0 as checked in.
4. **Keep the budgets.** See [Testing](#the-verification-gate); the line
   budgets and the named-test range (100–140) are enforced by
   `scripts/count_code.py`.

## Development environment

- MoonBit toolchain (developed against `moon 0.1.20260713`).
- Python 3 for the verification scripts.
- Windows 11 / PowerShell 5.1 (the `verify_all.ps1` script) or any shell for
  the individual `moon` commands.

## Working on the code

- **Source files** live at the repository root (`*.mbt`), in
  `cmd/weblink-tool/`, and in `examples/`. Tests live in root `test_*.mbt`.
- **Format with `moon fmt`** before committing changes. `moon fmt --check`
  must pass; `moon fmt` auto-inserts the `///|` doc markers the formatter
  expects, so run it rather than hand-placing them.
- **Never break determinism.** The property tests use fixed seeds; the audit
  iterates in a stable order; JSON member names serialize in sorted order.
  Do not introduce `random`, `time`, or hash-order iteration.
- **No panics on input.** Parser code must return `LinkError` for malformed
  input. If you add a parsing path, add malformed-input cases in
  `test_invalid.mbt` and truncation coverage in `test_truncation.mbt`.
- **Generated data.** `generated_relations.mbt` is generated. Do not edit it
  by hand; change `scripts/import_iana_relations.py` if the generator needs a
  change, then regenerate with
  `python scripts/import_iana_relations.py`.

## The verification gate

Before considering a change done, run the full gate from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1
```

This runs 34 steps:

1. `moon fmt --check`.
2. `moon check` / `moon build` / `moon test` for each of `wasm-gc`, `js`,
   `native` (9 steps).
3. Core CLI smoke tests (version, parse, canonicalize with mixed-case
   parameter names, relation lookup) on each target (12 steps).
4. CLI content assertions (stats, validate-malformed, audit-`rev`, linkset
   JSON emission).
5. The five examples plus the header → JSON → header round-trip assertion.
6. `scripts/count_code.py` — code-line budgets per area and the named-test
   count (100–140).
7. `scripts/verify_iana_snapshot.py` — snapshot sha256, record count, and
   `generated_relations.mbt` freshness.

The script prints `ALL CHECKS PASSED` on success and exits non-zero otherwise.

You can also run the individual pieces:

```sh
moon fmt --check
moon test --target native      # or wasm-gc / js
python scripts/count_code.py
python scripts/verify_iana_snapshot.py
```

## Reporting issues

Issues are tracked on the GitHub repository's issue tracker. When reporting,
include:

- the failing input (or the failing command),
- the `moon` version and target,
- the expected vs. actual output,
- whether the failure is a panic, a wrong result, or a budget/spec violation.

For suspected security issues, see [docs/security.md](docs/security.md).

## Code review notes

Reviewers should verify the four invariants that are easy to break:

1. **No panic on any input** (including truncations).
2. **Determinism** (fixed seeds, stable order).
3. **Canonical form stability** (idempotent `canonicalize`, fixed-point JSON).
4. **Budgets and test count** within the spec ranges.

## License

By contributing you agree that your contribution is made under the Apache-2.0
license (see [LICENSE](LICENSE)). The IANA registry data embedded in the
project is covered by its own provenance note in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
