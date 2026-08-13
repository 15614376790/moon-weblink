# Security

This document states the security posture of `moon-weblink`. It is written to
be read as an honest threat assessment, not a claim of completeness.

## Threat model

`moon-weblink` parses untrusted header-field values, linkset text and linkset
JSON. The primary threat is a hostile input causing a crash (panic), unbounded
resource consumption, or misleading output. The project does not handle
credentials, secrets, keys, or authenticated state, and it performs no I/O on
behalf of callers.

## What the parser guarantees

- **Never panics on input.** The parsing pipeline is single-pass and
  bounds-checked. Every malformed input yields a structured `LinkError`
  (`(stage, kind, offset, context)`), never a panic and never a partial
  success that is reported as a success.
- **Truncation safety.** For the corpus in `test_truncation.mbt`, **every
  byte-prefix** of every complex input is parsed without panicking (2504
  cases). This is a stronger property than "valid inputs work": it covers the
  classic crash class where a buffer is cut off mid-construct.
- **Bounds enforced by `Limits`.** Input length, link count, parameter count,
  name/value lengths, target length and extension length are all capped by the
  active `Limits` preset. Violations are `LinkError` (kind `limit`), not
  unbounded allocation. Three presets are provided — `default`, `strict`
  (for untrusted input), `permissive`.
- **Context excerpts are capped.** Error context strings are truncated to 80
  bytes, so a single pathological input cannot blow up the error string.

## What is not claimed

- **Not a general JSON parser.** The linkset JSON parser understands the RFC
  9264 structure and rejects shapes outside it; it is not a drop-in
  general-purpose JSON library.
- **Not a full URI validator.** `uri_ref.mbt` is RFC 3986 *syntax*-level. It
  does not normalize schemes, validate DNS names, or protect against
  scheme-based confusion (e.g. `javascript:` targets are not an attack for a
  parser, but a caller that uses link targets to drive navigation must apply
  its own allow-listing).
- **Not an SSRF defense.** This library never makes network requests. Any
  caller that *does* follow resolved link targets is responsible for its own
  destination policy.
- **Not a security review.** There is no formal external security audit; the
  guarantees above are asserted by the test suite and by code review within
  this project.

## No network, no secrets

- The IANA registry is a fully offline snapshot; no code path performs a
  network request at runtime.
- The project contains no credentials, tokens, keys, or endpoint
  configuration. Nothing in the library or CLI authenticates to anything.
- The CLI has no file I/O and no stdin reading in this MoonBit core; input is
  supplied as an argument, which avoids path traversal and file-prompting
  attack surface.

## Resource limits reference

| Preset | Intended use |
| --- | --- |
| `Limits::default()` | balanced default for library callers |
| `Limits::strict()` | tighter caps for untrusted input |
| `Limits::permissive()` | looser caps for known-good large collections |

The exact numeric caps are defined in `limits.mbt`; they are intentionally not
magic values duplicated in this document, so the code is the single source of
truth. `test_limits.mbt` asserts that over-limit inputs produce limit-kind
errors on every target.

## Reporting

Issues (including suspected security issues) should be reported through the
project's normal issue channel per [CONTRIBUTING.md](../CONTRIBUTING.md). There
is no private disclosure channel because there are no credentials or
deployment secrets to protect — the entire artifact is local and public.
