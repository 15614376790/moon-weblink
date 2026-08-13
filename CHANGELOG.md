# Changelog

All notable changes to `moon-weblink` are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The current version
is `0.1.0`. No tagged GitHub Release exists for this version (releases are
out of scope); the entry below covers the 0.1.0 development history.

## [0.1.0] - 2026-08-13

Version `0.1.0` is published to Mooncakes as `15614376790/moon-weblink`
(<https://mooncakes.io/package/15614376790/moon-weblink>).

### Added

- **RFC 8288 Web Linking core**
  - `link_parser.mbt`: strict link-value parsing with all target attributes
    (`anchor`, `hreflang`, `media`, `title`, `title*`, `type`) and extension
    parameters; case-insensitive ABNF parameter matching (RFC 5234); first-wins
    duplicate handling.
  - `link_serializer.mbt` + `canonicalize.mbt`: deterministic canonical
    serialization (lowercased names, fixed parameter order, sorted extension
    members).
  - `quoted_string.mbt`, `token.mbt`, `scanner.mbt`: shared lexical layer.
- **RFC 8187 extended parameter values** (`rfc8187.mbt`): `name*` parsing and
  a pure function serializer.
- **RFC 3986 URI-reference support** (`uri_ref.mbt`): syntax parsing and
  Section 5.2.2 reference resolution.
- **RFC 9264 Linkset**
  - `linkset_text.mbt`: `application/linkset` text format.
  - `linkset_json.mbt`: `application/linkset+json` with sorted member names.
  - `conversion.mbt`: semantics-preserving header ↔ text ↔ JSON conversion at
    the model boundary for the supported RFC 8288 / RFC 9264 scope.
- **Offline IANA registry**: 134 relation types in `generated_relations.mbt`
  generated from the pinned snapshot in `testdata/iana/`; `relation_registry.mbt`
  membership and lookup; `relation.mbt` helpers.
- **Query API** (`link_query.mbt`): `find_next`, `find_prev`, `find_canonical`,
  `find_alternate`, and `filter_by_relation` / `filter_by_type` /
  `filter_by_hreflang`.
- **Deterministic audit** (`audit.mbt`): deprecated `rev`, unregistered
  relation-lookalikes, `title`/`title*` coexistence, duplicate parameters,
  relative anchors, limit proximity.
- **Resource limits** (`limits.mbt`): `default`, `strict`, `permissive`
  presets; limit-kind structured errors.
- **Error model** (`error.mbt`): stable `(stage, kind)` pairs, UTF-8 byte
  offsets, capped context excerpts.
- **CLI** (`cmd/weblink-tool/`): `parse`, `validate`, `canonicalize`, `query`,
  `to-linkset-json`, `from-linkset-json`, `to-linkset-text`, `relation`,
  `audit`, `stats`, `version`, `help`.
- **Examples**: `parse_header`, `pagination`, `linkset_json`, `relation_query`,
  `audit_header`.
- **Verification tooling**: `scripts/verify_all.ps1` (34 steps),
  `scripts/count_code.py` (line budgets, named-test count),
  `scripts/verify_iana_snapshot.py` (snapshot integrity),
  `scripts/import_iana_relations.py` (snapshot → generated data).
- **Documentation**: README, architecture, specification map, testing,
  reproduction, security, limitations, renaming, CHANGELOG, CONTRIBUTING,
  third-party notices.
- **License**: Apache-2.0 `LICENSE`.

### Changed

- Module namespace renamed from `localdev/moon-weblink` (development
  placeholder) to `15614376790/moon-weblink`; see `docs/renaming.md` for the
  rename record.
- Release metadata finalized: `moon.mod` now declares version `0.1.0` and the
  repository URL; the CLI version banner is built from
  `@weblink.library_version()` (single version source alongside `moon.mod`).
- CLI argument normalization across MoonBit targets: js-style
  `[node, program.js, args...]` prefixes are stripped by
  `strip_program_name`, so every backend sees the same user arguments.
- Verification gate: the core CLI smoke tests (version, parse, canonicalize,
  relation) now run once per target (wasm-gc, js, native).

### Tests

- 147 named tests — 140 library blackbox tests across 16 `test_*.mbt` files
  plus 7 CLI argument-handling whitebox tests
  (`cmd/weblink-tool/cli_wbtest.mbt`) — passing on `wasm-gc`, `js` and
  `native`.
- 1200 deterministic property-test cases (fixed seeds; no `random`/`time`).
- 2504 truncation cases: every byte-prefix of the complex inputs is parsed and
  must never panic.
- Malformed-input corpus (`test_invalid.mbt`) asserting structured errors
  (stable `(stage, kind)`, sane offset, no panic).

### Security

- Parser never panics on input; truncation safety asserted by the corpus.
- Resource limits bound allocation; context excerpts capped at 80 bytes.
- Fully offline runtime; no credentials, no network, no file I/O in the CLI.
