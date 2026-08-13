# Limitations

This document states, honestly, what `moon-weblink` deliberately does **not**
do. It exists so that no reader mistakes a scope boundary for a bug.

## Protocol scope

- **Not a full HTTP client or server.** The project parses, serializes,
  converts, queries and audits link collections; it does not perform HTTP
  exchanges, caching, or request/response handling.
- **No scheme-specific URI semantics.** `uri_ref.mbt` implements RFC 3986
  reference *syntax* and resolution (Section 5.2.2). It does not normalize
  scheme case, punycode IDNs, default ports, percent-encoding of reserved
  characters, or any per-scheme rule. Two syntactically equivalent URIs are
  not necessarily byte-identical after resolution.
- **No non-HTTP link sources.** The anchor, hreflang, media, title and type
  target attributes are validated at the syntax level of the linked spec
  sections, but `moon-weblink` does not fetch the target of a link or validate
  it against the real resource.
- **No follow-through.** `find_next`/`find_prev`/`find_canonical`/`find_alternate`
  select links by relation; they do not dereference anything.

## Registry

- **The registry is a snapshot, not a live service.** The 134 relation types
  were pinned on 2026-08-11. New registrations after that date are unknown to
  the offline registry until the snapshot is refreshed with
  `python scripts/import_iana_relations.py --refresh` (explicit network opt-in;
  the normal generator run and the entire runtime are offline).
- **The registry answers membership, not semantics.** `relation_info` returns
  the snapshot's name/description/reference/notes fields. It does not interpret
  them.

## Parser edge cases

- **First-wins duplicates.** When a parameter name repeats within one
  link-value, the first occurrence wins; later duplicates are surfaced by the
  audit rather than silently rejected. This follows the RFC 8288 serialization
  rule but means a duplicate-bearing input is *not* an error.
- **Case preservation on input.** The parser records parameter names as they
  appear; case-insensitive *matching* and canonical *output* (lowercase) are
  separate, deliberate behaviors.
- **Ext-value strictness.** RFC 8187 decoding rejects malformed
  `charset'lang'value` forms; the parser will not guess at a broken ext-value.
- **No content negotiation.** The type/hreflang/media checks are textual; the
  project does not implement media-type range matching or language-range
  negotiation.

## Platform

- **No stdin/file I/O in the CLI.** In this MoonBit core there is no portable
  `fs`/`io`; `weblink-tool` reads input from `--input` or a positional
  argument. Piping large documents through stdin is not supported here.
- **No exit-code facility.** MoonBit `fn main` returns `Unit`; there is no
  portable process exit code, so the CLI reports success/failure as
  deterministic text on stdout. Scripts should grep the output rather than
  check `$LASTEXITCODE` semantics beyond the process running.
- **Windows PowerShell 5.1 argv.** Embedded double quotes cannot be passed
  through a native-command argument from PowerShell 5.1 (CommandLineToArgvW
  mangling). This affects how *you* invoke `weblink-tool` from PowerShell with
  JSON payloads, not the tool's behavior; the in-process example and the test
  suite cover JSON round-trips.
- **Case-insensitive matching is ASCII-only.** The ASCII fold in `token.mbt`
  lowercases `A`–`Z`; the link syntax itself is ASCII, so this matches the
  ABNF, but it is not general Unicode case folding.

## Non-goals

- **Not a test for production web servers.** The audit is deterministic and
  heuristic; it flags likely problems, it is not a validator that an HTTP
  origin must enforce.
- **No formal proof.** The no-panic guarantees are enforced by the test suite
  (truncation + malformed-input corpora), not by a formal verifier.
