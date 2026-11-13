The registry reference is `slowpilot/plot`.

Build the current SDK first, then run:

```sh
python3 release/prepare.py release/package.json
```

Set `SPUTNIK_ROOT` when the SDK checkout is not the sibling `sputnik-lang`.
The recipe creates publisher-scoped imports, exact package dependencies and
relocatable archives. `--modules bytecode` is supported for modules without
exported macros; mixed variants retain macro provider sources. Native packages
also support `--native prebuilt` on a tested target. Outputs are verified before
publication. Caches, credentials and interpreter installations are excluded.

Release 0.3.1 adds scene-v2 transport for interactive graph paper, tick steps
and typography in Notebook. Version 0.3.0 introduced data-aligned graph paper
and readable 2D export. The release provides source and bytecode modules with either source or
prebuilt native adapters, on macOS arm64 and Linux x86-64 GNU (eight variants).
Build native adapters on their actual target. For each platform:

```sh
for adapter in source prebuilt; do
  for modules in source bytecode; do
    python3 release/prepare.py release/package.json --native "$adapter" --modules "$modules"
  done
done
python3 release/verify.py
```

On Linux, pass `--platform linux-x86_64-gnu` to both tools. Verification installs
each archive into an isolated store, runs all 53 conformance checks plus file,
blob, snapshot, format, data-grid, zoom and typography fixtures, then checks the exact variant/hash lock.
Also run the native selftest described in the main README. Publish the checked
archives with the authenticated SDK CLI; the preparation tools never publish.
