# Renaming

This module ships as `localdev/moon-weblink` version `0.1.0-dev`. `localdev`
is a placeholder namespace; before publishing, moving the module to your own
namespace requires a small, mechanical rename. This document lists every place
that must change.

## What to change

### 1. `moon.mod`

Change the `name` line. Nothing else in `moon.mod` needs to move:

```
name = "your-namespace/moon-weblink"
```

The spec constraint forbids `repository`, `homepage`, `author`, `maintainer`
and `email` fields, so leave them out. Update `version` when you are ready to
publish (e.g. `0.1.0`).

### 2. Package `moon.pkg` files

Every `moon.pkg` in the module imports the library package by its full name.
There are three places:

- `cmd/weblink-tool/moon.pkg`
- `examples/*/moon.pkg` (five directories)

Each import line of the form

```
"localdev/moon-weblink"
```

must become

```
"your-namespace/moon-weblink"
```

### 3. Tests and examples that reference the module path

The tests import nothing by name (they live in the same package), but any
`@weblink.` references in examples go through the import in their `moon.pkg`;
changing step 2 fixes them all.

### 4. Documentation and metadata strings

The following text files mention the module name and are part of the
deliverable; update the occurrences of `localdev/moon-weblink`:

- `README.md` (module line, layout block, quick-start text)
- `docs/reproduction.md` (working-directory example)
- `docs/architecture.md` (layout description)
- `docs/renaming.md` (this file, at the top)

Also update the `description` in `moon.mod` only if your published description
differs.

## What does NOT need to change

- **Source files.** The library source uses `@weblink` only as an *alias*
  (defined in the importing `moon.pkg`); no `.mbt` file hard-codes the module
  path. `@weblink.` is a local alias, not the module name.
- **`generated_relations.mbt`.** Generated data contains no module path.
- **Scripts.** `count_code.py`, `verify_iana_snapshot.py` and
  `import_iana_relations.py` operate on relative paths and never reference the
  module name.
- **`verify_all.ps1`.** It uses `moon` with relative paths only.

## Verification after renaming

After changing the name, run the full gate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1
```

and confirm the module line in `moon.mod` shows your namespace:

```sh
moon info 2>&1 | head -n 5   # or: inspect moon.mod directly
```

The 25 steps (format, three targets, CLI, examples, budgets, IANA snapshot)
are all name-independent, so the only new risk from a rename is a missed
import string, which the build would catch immediately.

## Publishing

The project is hosted on GitHub; publishing to Mooncakes is **out of scope**
(no `moon login`, no `moon publish`). When you are ready to publish under your
own namespace, follow the MoonBit publishing guide, keeping in mind that this
document's rename steps must come first. If the GitHub repository is renamed,
update the git remote accordingly (`git remote set-url origin <new-url>`).
