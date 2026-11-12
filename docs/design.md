# Design

## One file

UPAL has one hard rule: a portable application is managed by exactly one file. That file contains the configuration, the engine, and the entry point. There is no sidecar config for the manager, no second binary, no hidden state.

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
| `copy` | portable → host | nothing | one-time snapshot; no link |
| `copy-sync` | both, at launch | `rsync` | approximate two-way sync; least reliable |
| `bind` | either | root + lifecycle | last resort |
| `none` | none | nothing | explicit opt-out |

`copy` is a one-time snapshot. `copy-sync` is the two-way hack: host changes are rsynced back into the folder at launch, then the folder is copied to the host before the app starts. It does not resolve conflicts and does not propagate deletions; it is the last resort after `link` and `env`.

Binaries use the same idea with a different unit: a command name, a source directory, and a target directory. `BIN_MODE` decides whether the folder owns the binaries or only links to the host's.

## Lifecycle

1. Resolve `PORTABLE_ROOT` from the runner's real path.
2. Preflight: filesystem type, writability, dry-run.
3. Resolve `PKG` and `BIN_NAMES`.
4. Detect binaries and data.
5. Install missing packages, one per `PKG` word, or call `app_install`.
6. Link binaries according to `BIN_MODE`.
7. Link data according to `DAT_METHOD`: move host data in on first link, back up conflicts as `.bak`.
8. Link and rewrite desktop files, icon, man pages.
9. Run `app_env`, `app_pre_link`, `app_post_link`.
10. Launch the application with the original arguments, or call `app_run`.
11. Close the terminal only when `KILL_TERMINAL=yes` and the runner has a controlling terminal.

The runner is idempotent. Running it twice changes nothing.

## Data first

UPAL is a portable data layer, not a portable binary format. The irreplaceable part is user data; binaries are disposable. The default is host-provided binaries, with the distro managing updates and security. Folder-owned binaries are an opt-in mode for offline use, a locally compiled build, or a self-contained folder.

This is why the data mapping is the center of the contract and the binary mode is secondary. A user can change `BIN_MODE` without touching the data; changing the data mapping is the decision that matters.

## Data reuse and version compatibility

Portable data is independent of the binary. The same folder can point at a distro package, a Flatpak, or a locally built binary. UPAL does not convert data between application versions or distributions; that is the user's decision. The safety net is a backup: `BACKUP="yes"` keeps the previous host data as `<path>.bak` before linking. Disable it only when you have your own backup.

## Data is per application

There is no global definition of valuable user data. A browser profile, a game save, a cache directory, and a plugin directory are all different decisions. The wrapper cannot know which ones matter.

Therefore:

- only redirect what the header names;
- data is on when `DAT_TARGET` is set;
- cache is off unless `CACHE_SOURCE` and `CACHE_TARGET` are both set;
- detection is a convenience, not a definition;
- the hook is the escape hatch for applications with several state directories.

This is why the configuration stays per runner instead of becoming a system-wide policy.

## Backends

Missing binaries are resolved through a backend, not bundled by default. `PACKAGE_MANAGER` selects it:

| Backend | Install | Run | Root |
|---|---|---|---|
| `auto` / `native` | `pkgcli` > `pkcon` > `apt`/`dnf`/`pacman`+`yay`/`zypper` | command on `PATH` | yes* |
| `distro` | native package manager only | command on `PATH` | yes |
| `flatpak` | `flatpak install` | `flatpak run "$FLATPAK_ID"` | no (user) |
| `snap` | `snap install` | `snap run "$PKG"` | yes |
| `nix` | `nix profile install` | `nix run` | no |
| `brew` | `brew install` | command on `PATH` | no |
| `toolpak`, `pkgit` | adapter-defined | adapter-defined | adapter-defined |
| `cpak` | `cpak install <source>` | `cpak run <pkg>` | adapter-defined |
| `none` | never | command on `PATH` | no |

\* `pkgcli` and `pkcon` may authenticate through polkit; the native package managers need root.

`auto` is the default and `native` is an alias. `distro` forces the distro manager only. The runner checks commands first, installs packages only when needed, and searches only when the package name is unknown. Ambiguous search results abort. A working host binary is never replaced.

A backend is an adapter, not an abstraction over a shared package API: each one owns its install and run commands. When the backend has no usable CLI, `app_install` and `app_run` take over. This is also how non-app stacks fit without adding a new engine.

## Privileges

The runner never invokes `sudo`. It runs as the user and stops when a step needs root: a system package install, a man-page link, or a link into a system directory. The message names the step and asks for a rerun with the available escalator (`sudo` or `doas`). Flatpak user installs and user-local links never need root. When the runner is elevated, `SUDO_USER`/`DOAS_USER` keep `HOME` pointed at the invoking user and created files are handed back to that user.

## Discovery tooling

A planned GTK tool wraps `strace`/`ptrace` to observe which paths an application touches, group them by XDG role, and suggest `DAT_TARGET`, `DAT_METHOD`, and `BIN_MODE`.

It is an authoring tool, not part of the runner. ptrace permissions, Flatpak sandboxes, and filesystem noise make tracing unsuitable for launch-time decisions. The runner keeps explicit configuration plus content detection; the GUI only writes the header.

## Flatpak profile

Flatpak is the ideal case: the paths are standardized, so the runner only needs `FLATPAK_ID`. `PACKAGE_MANAGER="flatpak"` derives the data path (`~/.var/app/$FLATPAK_ID`), installs with `flatpak install`, and runs with `flatpak run`.

The binary location is irrelevant to the runner because it never links the Flatpak binary. User installs live in `~/.local/share/flatpak/app/$FLATPAK_ID`; system installs live in `/var/lib/flatpak/app/$FLATPAK_ID`. The data path is the same for both.

Applications that write outside the sandbox data directory, such as Heroic with `~/Games`, need an explicit extra mapping in a hook. The standard path is automatic; the exception is opt-in.

## Non-app stacks

The abstraction is data plus a lifecycle, not an ELF binary. Immich is the proof: a Docker Compose web stack wrapped as one portable folder. The compose project directory is the data; `library/`, `postgres/`, and `run/` stay next to the manager file, and relative paths in the compose file make the folder movable.

The runner does not learn Docker. `app_run` starts the stack and opens the browser; `app_install` can pull images. One manager file remains the entry point. Helper scripts such as `up-immich` and `down-immich` are part of the stack, not additional managers.

## Multi-entry folders

A folder can hold several launchers. `ENTRIES` maps a name to a binary directory, an executable, a desktop file, and an icon. The engine installs each icon, rewrites each desktop `Exec=` to the runner plus the entry name, and launches the selected entry from its own directory. The header lists the entries; there is no per-application script. Data still maps through one `DAT_SOURCE`/`DAT_TARGET`, which is why Blender's version directories can share `dat/` while each desktop entry opens a different build.

## Icons

Any image in the portable root, or in `ICON_SOURCE`, becomes the icon; MIME type decides, not the extension. `ICON_NAME` pins one file.

The icon is installed into the hicolor theme under `ICON_ID` (default: the source filename without its extension), and the desktop entry uses `Icon=<id>`. This is the difference between a portable folder and a path-bound launcher: moving the folder leaves the desktop icon working. `ICON_METHOD="copy"` is the default and survives the move. `link` is smaller but breaks on move; the next run repairs it. `none` keeps the absolute path.

`gio` still sets the folder icon from the portable file. Deleting the image removes the managed theme icon, unsets the folder metadata, and falls back the desktop entry to the package or application name.

## Nautilus application bundles

The long-term interaction is a double-clickable folder, like a macOS bundle. Nautilus currently always browses a directory, and the public extension API has no hook for replacing activation. This is therefore a Nautilus patch, not a plugin.

The behavior is opt-in: only a directory with an explicit manifest is an application bundle. Normal directories keep opening normally. A global Nautilus preference controls the feature. The default is ask: the first launch of a bundle shows a confirmation. Bundles from a downloaded or extracted location always confirm, even when the preference allows local bundles.

```text
MyApp/
├── runner
├── application.json
├── icon.svg
└── dat/
```

```json
{
  "type": "application",
  "entry": "runner"
}
```

The manifest is optional desktop integration, like the icon and `.desktop` file. It is not a second manager; `runner` remains the only file that manages the app. The manifest name is provisional; `application.json` is the current proposal.

Rules:

- A valid manifest is required; a directory containing `run.sh` is not enough.
- `entry` must be a relative path inside the bundle. Reject absolute paths, `..`, and symlinks that escape the root.
- Downloaded or extracted bundles require confirmation before the first launch.
- An invalid manifest falls back to opening the directory and reports the error.

Implementation route: patch Nautilus, not an extension. Trace directory activation through `nautilus-files-view.c` and `nautilus-mime-actions.c`, build a minimal proof of concept in a fork, then discuss upstream. A generic activation-provider extension API is a later, larger project.

See [nautilus.md](nautilus.md) for the manifest, security rules, routes, and source investigation notes.

## Portable archives

A folder can be transported as a plain ZIP. The runner remains the only manager. A future unpack helper rejects zip-slip and symlink escapes, preserves the executable bit, and never runs anything after extraction.

AppManager interoperability is a possible opt-in adapter, not a dependency. See [packaging.md](packaging.md).

## POSIX first

The shell engine is the reference for three reasons:

1. The configuration is the header. A user can read and edit it without a compiler.
2. The behavior is transparent: `ln`, `mv`, `command -v`, and `findmnt` are visible.
3. It is the test oracle for any future engine.

The shell engine is about 260 lines and has no performance-sensitive work. A Rust port is justified by portability, not speed.

## Rust and Windows

A Rust engine is planned, not started. It must satisfy the same contract and pass the same fixtures as the shell engine.

The single-file rule shapes the design:

- The Rust binary embeds the engine and the per-application configuration. A small build step can produce a per-app runner from the same header, and the result is one executable.
- Runtime detection and environment overrides cover the zero-config case.
- A sidecar config file for the runner is not allowed. The optional Nautilus manifest is desktop integration, not runner configuration.

On Windows:

- Use a native binary. Do not ship a `.bat` + `.exe` pair.
- Directory links are junctions (`mklink /J` or the equivalent API) because symlinks need developer mode or elevation.
- Data paths are `%APPDATA%`, `%LOCALAPPDATA%`, and `%USERPROFILE%`, not XDG.
- The registry is not emulated. Applications that store state only in the registry are out of scope.
- The portable folder layout stays the same: runner, optional `bin`, optional `dat`, optional icon and desktop entry.

macOS is not a target. The Linux equivalent of a bundle is the opt-in Nautilus directory above, not a macOS `.app`. The existing Linux tools (`findmnt`, `gio`, `notify-send`, `/etc/os-release`) also have no direct equivalent there.

## Bind mounts

`bind` stays in the method table but is not implemented. It needs root, a mount/unmount lifecycle, and does not survive a reboot. Because the runner detaches the application, unmounting after exit needs a supervisor or a systemd unit. That is a different lifecycle from a symlink, not just another branch in a script.

It is the last resort for applications that replace symlinks. Document it, implement it only when a real application needs it.

## Non-goals

- macOS `.app` bundles as a format. The Linux equivalent is the opt-in Nautilus bundle above.
- Windows registry emulation.
- Data conversion between application versions or distributions. UPAL backs up; it does not migrate.
- A config file or a daemon for the runner. The Nautilus manifest is optional desktop integration.
- Bundling every library.
- A GUI in the runner. The discovery tool is a separate authoring aid.
- A package format. UPAL is a layer over the host's package manager, not a replacement.

## Roadmap

1. Freeze the contract in this repository.
2. Harden the POSIX engine: safety, dry-run, tests.
3. Add `env`, `link-out`, `copy`, `copy-sync`, auto-detection, and the backend adapters.
4. Port the proof-of-concept runners and add hooks to the template updater.
5. Add XDG mapping, Flatpak, Snap, Nix, Homebrew, and the search fallback.
6. Build the GTK discovery tool on `strace`/`ptrace`.
7. Prototype Nautilus directory activation in a fork, then propose it upstream.
8. Define the ZIP archive and safe unpacking; talk to AppManager only after both projects are ready.
9. Build the Rust engine against the same fixtures.
10. Add Windows support as a native binary.
