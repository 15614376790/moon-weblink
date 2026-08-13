# moon-weblink

A strict RFC 8288 **Web Linking** and RFC 9264 **Linkset** parser, serializer,
converter, query and audit toolkit for MoonBit.

`moon-weblink` parses, serializes, converts, queries and audits link collections
in all three representations RFC 8288 / RFC 9264 define — the HTTP `Link` header
field, the `application/linkset` text format, and the `application/linkset+json`
format — over one shared model. It ships an offline snapshot of the IANA Link
Relation Types registry, a deterministic audit layer, bounded resource limits,
and structured errors with UTF-8 byte offsets.

- Module: `15614376790/moon-weblink` (version `0.1.0-dev`)
- Targets: `wasm-gc`, `js`, `native`
- License: Apache-2.0
- Repository: <https://github.com/15614376790/moon-weblink>

## Features

- **RFC 8288 `Link` header parsing and serialization** — link-values,
  target attributes (`anchor`, `hreflang`, `media`, `title`, `title*`, `type`),
  extension parameters, first-wins duplicate handling, and a deterministic
  canonical form.
- **RFC 8187 extended values** — `title*` and `name*` parameters, full
  charset/language/percent-decoding, plus a pure function serializer.
- **RFC 3986 URI-reference support** — a minimal but strict parser and
  reference resolution (`Section 5.2.2`), used for targets, anchors and
  resolving relative links.
- **RFC 9264 Linkset** — both `application/linkset` (multiline text) and
  `application/linkset+json`, with lossless conversion at the model level
  between the header, text and JSON forms.
- **Offline IANA registry** — 134 relation types bundled as a generated
  snapshot (see `testdata/iana/`); membership checks never touch the network.
- **Query API** — find and filter links by relation type, media type and
  hreflang; `next` / `prev` / `canonical` / `alternate` helpers.
- **Deterministic audit** — flags the deprecated `rev`, relation types that
  look registered but are not, `title`/`title*` coexistence, duplicates,
  relative anchors and out-of-limits values.
- **Resource limits** — `default`, `strict` and `permissive` presets bounded
  by input size, link count, parameter count, name/value sizes and more.
- **Structured errors** — `LinkError` with a stable `(stage, kind)` pair, a
  UTF-8 byte offset into the input, and a context excerpt capped at 80 bytes.
- **CLI** — `weblink-tool` subcommands to parse, validate, canonicalize,
  query, convert, look up relations and audit.
- **Safety** — truncation-safe (every byte-prefix of any input never panics)
  and malformed-input-safe; 140 named tests pass on all three targets.

## Layout

```
moon.mod                 module manifest (15614376790/moon-weblink 0.1.0-dev)
lib source (.mbt)        parser, serializer, model, linkset, audit, query, ...
cmd/weblink-tool/        command-line tool
examples/                five runnable example programs
testdata/iana/           offline IANA registry snapshot (CSV + SOURCE.json)
scripts/                 verification and generation helpers
docs/                    design and process documentation
```

## Quick start

Requires the MoonBit toolchain. From the repository root:

```sh
moon check --target native
moon test --target native
moon run cmd/weblink-tool -- parse --input '<https://example.com/page/2>; rel="next"'
moon run examples/pagination
```

Verify everything (formatting, all three targets, CLI, examples, line
budgets, IANA snapshot):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1
```

## Library usage

```moonbit
fn main {
  // Parse a Link header field value into a shared model.
  let links = @weblink.parse_link_header(
    "</users?page=2>; rel=\"next\", </users?page=1>; rel=\"prev\"",
    @weblink.Limits::default(),
  )

  match links {
    Err(e) => println("error: \{e.to_display()}")
    Ok(links) => {
      // Query helpers: find next/prev, filter by relation or media type.
      match @weblink.find_next(links) {
        Some(next) => println("next: \{next.target()}")
        None => println("no next link")
      }
      // Convert the whole collection to application/linkset+json and back.
      let json = @weblink.serialize_linkset_json(
        @weblink.LinkSet::from_links(links),
      )
      println(json)
    }
  }
}
```

## CLI

The CLI reads its input from `--input` (or the first positional). There is no
stdin or file I/O in this MoonBit core, and `fn main` must return `Unit`
(there is no portable exit code), so every command reports its outcome as one
deterministic line of stdout text, safe to script by grepping.

```sh
weblink-tool parse            parse a Link header and print each link
weblink-tool validate         report valid / invalid
weblink-tool canonicalize     emit the canonical Link header form
weblink-tool query            find links by --rel / --type / --hreflang
weblink-tool to-linkset-json  convert a Link header to application/linkset+json
weblink-tool from-linkset-json convert application/linkset+json to a Link header
weblink-tool to-linkset-text  convert to application/linkset text
weblink-tool relation         query the offline IANA relation registry
weblink-tool audit            audit a Link header for issues
weblink-tool stats            library and registry statistics
weblink-tool version | help
```

`--limits` selects the `default`, `strict` or `permissive` resource limit
preset; `--json` switches the parse and audit output to machine-readable JSON.

## Examples

| Example | What it shows |
| --- | --- |
| `examples/parse_header` | parse a `Link` header and print each link |
| `examples/pagination` | walk `next` / `prev` pagination links; resolve a relative URI against a base |
| `examples/linkset_json` | convert `Link` header → linkset JSON → header |
| `examples/relation_query` | query the offline IANA registry; filter links by relation |
| `examples/audit_header` | run the deterministic audit and print every finding |

## Documentation

- [Architecture](docs/architecture.md) — modules, data model, error model, determinism.
- [Specification map](docs/specification-map.md) — every RFC requirement and where it is implemented.
- [Testing](docs/testing.md) — the 140 tests, property and truncation corpora, targets.
- [Reproduction](docs/reproduction.md) — how to reproduce every number in this README.
- [Security](docs/security.md) — parser safety, resource limits, no network, no secrets.
- [Limitations](docs/limitations.md) — what this toolkit deliberately does not do.
- [Renaming](docs/renaming.md) — record of the completed `localdev/moon-weblink` → `15614376790/moon-weblink` namespace rename, and how to rename again.
- [CHANGELOG](CHANGELOG.md) — release history.
- [CONTRIBUTING](CONTRIBUTING.md) — how to build, test and contribute.
- [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) — IANA registry data provenance.

## Measured numbers

Reproduced by `scripts/count_code.py` and `scripts/verify_iana_snapshot.py`:

- 140 named tests, all passing on `wasm-gc`, `js` and `native`.
- 1200 deterministic property-test cases (fixed seeds) + 2504 truncation
  (prefix, parser) cases — every byte-prefix of the complex inputs parses
  without panicking.
- Code lines (blank and comment lines excluded): core 3400, CLI + examples
  784, tests 1958, total 6142.
- 134 relation types in the offline IANA snapshot; the checked-in
  `generated_relations.mbt` matches the snapshot byte-for-byte.

## License

Apache-2.0. The IANA registry data embedded in this project is from the IANA
Link Relation Types registry; see [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
