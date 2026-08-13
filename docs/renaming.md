# Module rename record

This document records the completed namespace rename of this module and
explains how to perform another rename in the future.

## Completed rename

```text
localdev/moon-weblink
→
15614376790/moon-weblink
```

Done in commit `chore: rename module namespace to 15614376790/moon-weblink`.
The old `localdev` namespace was a development placeholder; the module now
lives under the owner's real GitHub namespace
(<https://github.com/15614376790/moon-weblink>).

No runtime reference to the old namespace remains: `moon.mod` and every
`moon.pkg` import use the new namespace. Verify with:

```sh
git grep "localdev/moon-weblink"
```

Only this rename record may mention the old namespace.

## What changed

- `moon.mod` — module name.
- `cmd/weblink-tool/moon.pkg` — library import.
- `examples/*/moon.pkg` (five directories) — library import.
- `README.md`, `CONTRIBUTING.md` — module references.
- `cmd/weblink-tool` version banner — module name printed by `version` and
  `stats`.

The library source never hard-codes the module path: consumers import the
module by its full name and alias it (`@weblink`), so a rename only touches
`moon.pkg` import lines plus documentation. No `.mbt` library file contains
the module name.

## Renaming again in the future

To move the module to another namespace, change:

1. `moon.mod` — `name = "your-namespace/moon-weblink"`.
2. Every `moon.pkg` that imports the library by full name:
   `cmd/weblink-tool/moon.pkg` and `examples/*/moon.pkg`.
3. Documentation strings that mention the module name (README, CONTRIBUTING,
   CHANGELOG, this file).

Then re-run the full gate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1
```

A missed import string fails the build immediately, so the gate is the
authoritative check.

## Publishing

The project is hosted on GitHub; publishing to Mooncakes is **out of scope**
(no `moon login`, no `moon publish`). If the GitHub repository is renamed,
update the git remote accordingly (`git remote set-url origin <new-url>`).
