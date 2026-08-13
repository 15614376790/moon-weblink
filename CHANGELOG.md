# Changelog

All notable changes to `moon-weblink` are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project is at
version `0.1.0-dev`; there is no released version yet, so there are no tagged
releases. This file records the development history of the working tree.

## [Unreleased]

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
  - `conversion.mbt`: lossless header ↔ text ↔ JSON conversion at the model
    boundary.
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
- **Verification tooling**: `scripts/verify_all.ps1` (25 steps),
  `scripts/count_code.py` (line budgets, named-test count),
  `scripts/verify_iana_snapshot.py` (snapshot integrity),
  `scripts/import_iana_relations.py` (snapshot → generated data).
- **Documentation**: README, architecture, specification map, testing,
  reproduction, security, limitations, renaming, CHANGELOG, CONTRIBUTING,
  third-party notices.
- **License**: Apache-2.0 `LICENSE`.

### Tests

- 140 named tests across 16 `test_*.mbt` files, passing on `wasm-gc`, `js` and
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
