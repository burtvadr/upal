# Portable archives and AppManager

## ZIP transport

A portable folder can be zipped into one file:

```bash
(cd MyApp && zip -r ../MyApp.zip .)
unzip MyApp.zip -d MyApp/
./MyApp/runner
```

The archive root is the portable root: runner, optional `application.json`, `bin/`, `dat/`, icon, desktop file. The runner stays the only manager file.

## Unpack safety

An optional `upal-unpack` helper should:

- reject absolute paths and `..` entries;
- reject symlinks or verify their targets stay inside the root;
- preserve the executable bit on the runner;
- never execute anything after extraction.

A downloaded archive is untrusted. Zip-slip and symlink escape are the real risks; checksums identify the archive but do not make it safe.

## AppManager

[AppManager](https://github.com/kem-a/AppManager) installs and updates AppImages, and can keep `.home` and `.config` next to the AppImage. The overlap with UPAL is portable data, not package format.

Possible integration, only if the AppManager maintainers want it and UPAL is mature enough:

- AppManager imports or launches a UPAL folder or archive.
- UPAL exports a folder that AppManager can list and launch.
- Both read the same optional manifest for the entry point.

No dependency, no format merge, no assumed upstream changes.

## Conditions

1. Stabilize the runner and data contract.
2. Stabilize the manifest.
3. Write the archive spec and unpack rules.
4. Ask the AppManager maintainers.
5. Build the adapter only if both projects agree.

Status: idea. No code.
