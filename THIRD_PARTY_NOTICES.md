# Third-party notices

`moon-weblink` is original MoonBit code written for this project. It has no
third-party MoonBit or runtime dependencies: the library imports only the
MoonBit core (`moonbitlang/core`) that ships with the toolchain. The only
external data incorporated is the IANA Link Relation Types registry, described
below.

## IANA Link Relation Types registry (data)

The registry membership data used by the offline registry
(`relation_registry.mbt`) is a snapshot of the public **IANA Link Relation
Types** registry, obtained from:

- Registry: <https://www.iana.org/assignments/link-relations>
- CSV source: <https://www.iana.org/assignments/link-relations/link-relations-1.csv>

The snapshot is pinned at retrieval time and stored under `testdata/iana/`:

- `testdata/iana/link-relations.csv` — the raw registry CSV (134 records).
- `testdata/iana/SOURCE.json` — provenance metadata: source URL, retrieval
  date (2026-08-11), sha256
  `37109cf6ccf9e4e5e035e8ca1d2fb9f41f5972f7656c033f07e9c58a66769dd4`, and the
  record count.

The registry data is generated from this snapshot into
`generated_relations.mbt` by `scripts/import_iana_relations.py` and verified
by `scripts/verify_iana_snapshot.py`. The MoonBit runtime never accesses the
IANA site; the data is used offline.

The IANA registry content is public data published by IANA. Its incorporation
here is factual data, not creative work; it is reproduced for the purpose of
registry membership and reference lookups. The project does not claim
ownership of, and does not assert a copyright on, the IANA registry data
itself.

## Licenses

- **`moon-weblink` source code** — Apache License 2.0, see [LICENSE](LICENSE).
- **MoonBit core library** — part of the MoonBit toolchain distribution
  (`moonbitlang/core`), under the toolchain's own license; this project does
  not redistribute it.
- **IANA registry data** — public registry data as described above.

## Tooling

The verification scripts use the Python 3 standard library only
(`csv`, `hashlib`, `io`, `json`, `sys`, `argparse`, `urllib.request` for the
explicit `--refresh` opt-in). No third-party Python packages are required.
