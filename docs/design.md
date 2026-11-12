# Design

## One file

UPAL has one hard rule: a portable application is managed by exactly one file. That file contains the configuration, the engine, and the entry point. There is no sidecar config, no second binary, no hidden directory.

Two implementations are allowed:

- **POSIX shell** — the reference. The header is editable, the engine is visible, and there is no build step.
- **Native binary** — a future Rust engine. The binary embeds the engine and a per-application configuration, so it is still one file.

A `.bat` shim plus an `.exe` engine is two files. It is not UPAL. On Windows the single file must be the native binary.

## The primitive

Every filesystem decision is one call:

```text
redirect <portable> <host> <method>
```

| Method | Direction | Needs | Notes |
|---|---|---|---|
| `link` | host → portable | nothing | default; the app may replace symlinks |
| `link-out` | portable → host | nothing | reference mode, not portable |
| `env` | none | the app respects the variable | per-process, reversible |
| `bind` | either | root + lifecycle | last resort |
| `none` | none | nothing | explicit opt-out |

Binaries use the same idea with a different unit: a command name, a source directory, and a target directory. `BIN_MODE` decides whether the folder owns the binaries or only links to the host's.

## Lifecycle

1. Resolve `PORTABLE_ROOT` from the runner's real path.
2. Preflight: filesystem type, writability, dry-run.
3. Resolve `PKG` and `BIN_NAMES`.
4. Detect binaries and data.
5. Install missing packages, one per `PKG` word.
6. Link binaries according to `BIN_MODE`.
7. Link data according to `DAT_METHOD`: move host data in on first link, rotate conflicts.
8. Link and rewrite desktop files, icon, man pages.
9. Run `app_env`, `app_pre_link`, `app_post_link`.
10. Launch the application with the original arguments.
11. Close the terminal only when `KILL_TERMINAL=yes`.

The runner is idempotent. Running it twice changes nothing.

## Data is per application

There is no global definition of valuable user data. A browser profile, a game save, a cache directory, and a plugin directory are all different decisions. The wrapper cannot know which ones matter.

Therefore:

- only redirect what the header names;
- data is on when `DAT_TARGET` is set;
- cache is off unless `CACHE_SOURCE` and `CACHE_TARGET` are both set;
- detection is a convenience, not a definition;
- the hook is the escape hatch for applications with several state directories.

This is why the configuration stays per runner instead of becoming a system-wide policy.

## POSIX first

The shell engine is the reference for three reasons:

1. The configuration is the header. A user can read and edit it without a compiler.
2. The behavior is transparent: `ln`, `mv`, `command -v`, and `findmnt` are visible.
3. It is the test oracle for any future engine.

The shell engine is roughly 200 lines and has no performance-sensitive work. A Rust port is justified by portability, not speed.

## Rust and Windows

A Rust engine is planned, not started. It must satisfy the same contract and pass the same fixtures as the shell engine.

The single-file rule shapes the design:

- The Rust binary embeds the engine and the per-application configuration. A small build step can produce a per-app runner from the same header, and the result is one executable.
- Runtime detection and environment overrides cover the zero-config case.
- A sidecar config file is not allowed.

On Windows:

- Use a native binary. Do not ship a `.bat` + `.exe` pair.
- Directory links are junctions (`mklink /J` or the equivalent API) because symlinks need developer mode or elevation.
- Data paths are `%APPDATA%`, `%LOCALAPPDATA%`, and `%USERPROFILE%`, not XDG.
- The registry is not emulated. Applications that store state only in the registry are out of scope.
- The portable folder layout stays the same: runner, optional `bin`, optional `dat`, optional icon and desktop entry.

macOS is not a target. A `.app` is a metadata-driven bundle, which conflicts with the no-metadata rule. The existing Linux tools (`findmnt`, `gio`, `notify-send`, `/etc/os-release`) also have no direct equivalent there.

## Bind mounts

`bind` stays in the method table but is not implemented. It needs root, a mount/unmount lifecycle, and does not survive a reboot. Because the runner detaches the application, unmounting after exit needs a supervisor or a systemd unit. That is a different lifecycle from a symlink, not just another branch in a script.

It is the last resort for applications that replace symlinks. Document it, implement it only when a real application needs it.

## Non-goals

- macOS `.app` bundles.
- Windows registry emulation.
- A config file or a daemon.
- Bundling every library.
- A GUI.
- A package format. UPAL is a layer over the host's package manager, not a replacement.

## Roadmap

1. Freeze the contract in this repository.
2. Harden the POSIX engine: safety, dry-run, tests.
3. Add `env`, `link-out`, and auto-detection.
4. Port the proof-of-concept runners and add hooks to the template updater.
5. Add XDG mapping and Flatpak support.
6. Build the Rust engine against the same fixtures.
7. Add Windows support as a native binary.
