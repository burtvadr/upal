# Portable archives and AppManager

## The idea

A portable folder can be zipped into one file for transport. Copy the file, unzip it on the other machine, click the runner. This borrows the "one file" convenience of an APK without adopting the Android package format.

The archive is not an installer and it does not execute anything on extraction. It is a snapshot of a portable folder.

## What the archive is

- A plain ZIP. Any ZIP tool can open it.
- The root of the archive is the portable root.
- The runner remains the only manager file.
- `application.json` is optional desktop integration, not a second manager.
- A `.upal` extension is optional sugar; `unzip app.upal` works because the bytes are ZIP.

```text
MyApp/
├── runner
├── application.json
├── bin/
├── dat/
├── icon.svg
└── MyApp.desktop
```

```bash
(cd MyApp && zip -r ../MyApp.upal .)
unzip MyApp.upal -d MyApp/
./MyApp/runner
```

The runner is still the thing that installs missing packages, links data, and launches the app. The archive only moves the folder.

## APK comparison

| | APK | UPAL archive |
|---|---|---|
| Container | ZIP | ZIP |
| Manifest | `AndroidManifest.xml` | optional `application.json` |
| Code | `classes.dex` | host package, local build, or `bin/` |
| Signing | required by Android | none yet |
| Runtime | Android | the host OS |
| Install | Android package manager | unzip and click |
| Auto-run on open | no | no |

The similarity is the single-file transport. The formats are not compatible.

## Unwrap tool

Standard `unzip` is enough. An optional `upal-unpack` helper can make extraction safer:

- reject absolute paths and `..` entries (zip-slip);
- reject symlinks or verify that their targets stay inside the root;
- preserve the executable bit on the runner;
- validate the manifest before suggesting a launch;
- never execute anything after extraction.

The helper is a separate utility, not a manager. It does not change the single-file rule.

## Security

- A downloaded archive is untrusted until the user inspects it. Do not auto-run the runner.
- Zip-slip and symlink escape are the main extraction risks. The helper must resolve the final path and confirm it stays inside the destination.
- ZIP stores Unix permissions in external attributes, but not every tool preserves them. If the runner is not executable, `chmod +x runner`.
- Checksums and signatures are useful later. They prove who built the archive, not that the app is safe.
- The manifest is a declaration, not a security boundary.

## AppManager

[AppManager](https://github.com/kem-a/AppManager) is a GTK/Vala utility that installs and updates AppImages. It already has a portable mode: it can keep `.home` and `.config` next to the AppImage, wire desktop entries, and update apps in the background.

The overlap with UPAL is portable data, not package format:

- AppManager manages AppImages;
- UPAL manages arbitrary apps and their data;
- both want the app and its state to stay together.

Possible integration, only if the AppManager maintainers want it and UPAL is mature enough:

- AppManager imports or launches a UPAL folder or archive.
- UPAL exports a folder that AppManager can list and launch.
- Both read the same optional manifest for the entry point.

This is not a dependency, not a merge of formats, and not an assumption of upstream changes. AppManager stays AppImage-focused; UPAL stays a portable data layer over the host's package manager or folder-owned binaries.

## Conditions

Do not start the integration yet. First:

1. Stabilize the runner and the data contract.
2. Stabilize the manifest (`application.json` is still provisional).
3. Write the archive spec and the safe unpack rules.
4. Ask the AppManager maintainers whether the overlap is useful to them.
5. Build the adapter only if both projects agree.

Status: idea. No code.
