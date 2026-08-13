# Architecture

This document describes the internal structure of `moon-weblink`: the source
layout, the shared data model, the parsing pipeline, the serializer, the
linkset converters, the offline registry, the audit layer and the error model.
It is written for contributors; for a feature-level overview see the
[README](../README.md).

## Source layout

The library is a single MoonBit package rooted at `moon.mod`. All non-test
`.mbt` files in the root form the core; `generated_relations.mbt` is generated
by [scripts/import_iana_relations.py](../scripts/import_iana_relations.py) and
is excluded from the line budgets.

```
core (library)
  scanner.mbt        low-level character scanning helpers
  token.mbt          ASCII token classification and case folding
  quoted_string.mbt  RFC 7230 quoted-string scanning
  parameter.mbt      link-param parsing (name; value handling)
  model.mbt          WebLink, LinkParam, LinkSet, RelationInfo types
  error.mbt          LinkError, LinkErrorStage, LinkErrorKind, Limits
  limits.mbt         resource-limit presets and enforcement
  link_parser.mbt    RFC 8288 link-value parsing
  link_serializer.mbt serialization to the Link header form
  canonicalize.mbt   deterministic canonical form
  rfc8187.mbt        RFC 8187 ext-value decoding and encoding
  uri_ref.mbt        minimal RFC 3986 URI-reference parsing + resolution
  relation.mbt       registered-relation membership helpers
  relation_registry.mbt offline IANA registry lookup (built on the generated data)
  generated_relations.mbt GENERATED — the offline registry data itself
  linkset_text.mbt   application/linkset (text) parse + serialize
  linkset_json.mbt   application/linkset+json parse + serialize
  conversion.mbt     header <-> linkset <-> json conversion entry points
  link_query.mbt     query helpers: find/filter by relation, type, hreflang
  audit.mbt          deterministic audit of a parsed collection

cmd/weblink-tool/    the command-line tool (cli.mbt, commands.mbt, output.mbt, main.mbt)
examples/            five runnable example programs, one directory each
```

## Shared data model

`model.mbt` defines the types that all three representations (Link header,
linkset text, linkset JSON) convert to and from.

- `WebLink` — one link-value: a target, a relation-set (ordered list of
  relation strings), and a list of `LinkParam` target attributes. The parser
  keeps first-wins duplicate semantics: when the same parameter name appears
  twice, the first occurrence wins and later duplicates are recorded in the
  audit rather than silently dropped.
- `LinkParam` — `(name, value)` with an `extended` flag distinguishing the
  RFC 8187 `name*` form from the plain form.
- `LinkSet` — an ordered collection of `WebLink`. It is the model backing all
  three wire formats.
- `RelationInfo` — one IANA registry entry: `name`, `description`,
  `reference`, `notes`.

Parameter names are stored verbatim (the parser records exactly what appeared)
but are interpreted case-insensitively: RFC 5234 ABNF literals such as `rel`
and `anchor` are matched with a case-insensitive ASCII fold (see `token.mbt`),
and the canonical serializer emits the lowercase form.

## Parsing pipeline

`link_parser.mbt` walks a single RFC 8288 link-value grammar nonterminals in
order — `link-value`, `link-param`, `quoted-string`, `extension` — over the
characters of the input. The scanner is a single left-to-right pass over the
UTF-8 bytes; every position is bounded by `Limits` (see below). `parse_link_header`
accepts a comma-separated list of link-values and returns
`Result[Array[WebLink], LinkError]`.

Design rule: **the parser never panics on input**. Any malformed input yields
`Err` (or, for inputs that end in the middle of a construct, a structured
error whose context excerpt is capped at 80 bytes). Truncation safety — every
byte-prefix of any accepted input still parses without panicking — is enforced
by a dedicated test corpus (see [testing.md](testing.md)).

## Limits

`limits.mbt` defines `Limits` and three presets:

| Preset | Use |
| --- | --- |
| `Limits::default()` | balanced default, recommended for library callers |
| `Limits::strict()` | tighter caps, for untrusted input |
| `Limits::permissive()` | looser caps, for known-good large collections |

The limit struct bounds input length, link count per collection, parameter
count per link, parameter name length, parameter value length, target length,
extension-token length and similar. Exceeding any bound is reported as a
structured `LinkError` (kind `limit`), never a panic.

## Serializer and canonical form

`link_serializer.mbt` emits the RFC 8288 `Link` header form from a `WebLink`.
`canonicalize.mbt` produces a **deterministic canonical form**: relation types
are serialized first, target attributes follow in a fixed parameter order
(`anchor`, `hreflang`, `media`, `title`, `title*`, `type`, then extensions in
stable sorted order), parameter names are lowercased, and a single space
separates parameters. The canonical form is what `weblink-tool canonicalize`
prints and what the round-trip tests assert against, so equivalent inputs
produce byte-identical output.

## RFC 8187

`rfc8187.mbt` implements extended parameter values (`name*`): the
`charset'lang'value` syntax, percent-decoding of UTF-8, and a pure function
serializer that re-encodes a string. Decoding failures are errors, not panics.

## URI reference support

`uri_ref.mbt` is a minimal but strict RFC 3986 URI-reference parser plus
reference resolution per RFC 3986 Section 5.2.2 (merge + remove-dot-segments).
It is used to validate `anchor` and target fields and by the `pagination`
example to resolve a relative target against a base URI. It deliberately does
not attempt scheme-specific semantics.

## Linkset text and JSON

- `linkset_text.mbt` parses and serializes `application/linkset` (the
  multiline text format of RFC 9264).
- `linkset_json.mbt` parses and serializes `application/linkset+json` per
  RFC 9264 Section 4.2: a top-level `"linkset"` array of objects, one member
  per relation, whose values are arrays of link objects. For canonical output
  the relation and extension member names are emitted in a stable sorted order
  so serialization is a fixed point.

`conversion.mbt` provides the entry points that convert at the model level, so
conversions are semantics-preserving at the `LinkSet` boundary for the
supported RFC 8288 / RFC 9264 scope:

- header → `LinkSet` → linkset text
- header → `LinkSet` → linkset JSON
- linkset JSON → `LinkSet` → header

## Offline IANA registry

`relation_registry.mbt` answers `is_registered_relation`, `relation_info`,
`registered_relations` and `registered_relation_count` from
`generated_relations.mbt`, which is generated offline from the pinned CSV
snapshot in [testdata/iana/](../testdata/iana/). The runtime never touches the
network; the snapshot integrity is verified by
[scripts/verify_iana_snapshot.py](../scripts/verify_iana_snapshot.py).

## Audit

`audit.mbt` runs a deterministic, order-stable pass over a parsed collection
and reports `AuditIssue`s with a severity (`Info`, `Warning`, `Error`). Checks
include the deprecated `rev` parameter, relation types that match a
registered-relation prefix but are not registered, coexistence of `title` and
`title*`, duplicate first-wins parameters, relative anchors, and values that
push against the active limits. The audit never mutates its input.

## Error model

`error.mbt` defines:

- `LinkErrorStage` — where the error happened (scan, parse, linkset, json,
  uri, limit, rfc8187, serialize, ...).
- `LinkErrorKind` — what kind of failure (syntax, unknown, limit, decode,
  ...).
- `LinkError` — `(stage, kind, offset, context, to_display)`: `offset` is the
  UTF-8 byte offset into the input, and `context` is a capped excerpt around
  it. `to_display` renders `stage::kind at byte <offset>: <context>`, which is
  what the CLI prints as `error: ...`.

The `(stage, kind)` pair is stable across releases, which makes the error
strings safe to assert against in tests and in scripts.

## Determinism

Everything that can be made deterministic is:

- The canonical serializer (fixed parameter order, lowercased names, sorted
  extensions).
- Linkset JSON serialization (sorted member names).
- The audit (fixed check order, stable iteration).
- Property tests use fixed seeds (no `random`/`time`); see
  [testing.md](testing.md).
