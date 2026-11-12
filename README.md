# upal

**Universal Portable Abstraction Layer** — one file that turns an application into a portable folder.

UPAL is a portable data layer first and a launcher second. The folder owns the user data; the binaries are disposable. They can come from the host package manager, a local build, or the folder itself. Move the folder, click the runner, and the app continues where it left off.

## The single-file rule

One file manages the portable application. That file is the runner, the configuration, and the engine. No sidecar config, no second binary, no hidden metadata.

- **POSIX shell** — the reference implementation. Editable header, no build step.
- **Native binary** — future Rust engine. Same contract, same behavior, still one file.

A folder with two manager files is not UPAL.

> **Status:** this repository documents the full contract and ships a working reference template. The template currently implements explicit data links and binary link-out. The `env`, `link-out`, binary `in`, auto-detection, and dry-run layers are specified in the docs and are the next implementation step.

## Why

Most Linux packages split an application across paths the user does not control:

- binaries in `/usr/bin`, `/opt`, or `/var/lib/flatpak`;
- configuration in `~/.config`;
- data in `~/.local/share`;
- state in `~/.local/state`;
- cache in `~/.cache`;
- Flatpak data in `~/.var/app`.

The result is that a backup, a move to another drive, or a copy to another machine means hunting through several directories. UPAL replaces that with one folder:

## Data first, binaries disposable

The irreplaceable part is user data: profiles, saves, plugins, configuration, state. Binaries can be reinstalled or rebuilt. UPAL therefore defaults to host-provided binaries and treats folder-owned binaries as an optional mode.

- **Host-provided** (`in`, or host mode with no `bin/`) — the distro manages updates and security.
- **Folder-owned** (`out`, `copy`) — offline use, a self-contained folder, or a locally compiled build.
- **No binaries at all** — click and run; the package manager installs them.

A locally compiled application fits the same model: put the binary in `bin/`, set `BIN_MODE="copy"`, and keep the data mapping.

The layout:

```text
MyApp/
├── runner          # the only manager file
├── bin/            # optional: links to host binaries, or real binaries
├── dat/            # optional: portable user data
├── icon.svg        # optional: first image becomes the icon
└── MyApp.desktop   # optional: desktop entry
```

The runner resolves its own location, so the folder can be renamed or moved. The names `bin` and `dat` are defaults, not requirements: the header can point anywhere, and the engine can detect the roles by contents.

## Quick start

```sh
mkdir -p ~/Apps/GIMP/dat
cp posix_variables ~/Apps/GIMP/runner
chmod +x ~/Apps/GIMP/runner
$EDITOR ~/Apps/GIMP/runner
```

Edit the header:

```sh
PKG="gimp"
DAT_TARGET="$HOME/.config/GIMP"
```

Run it:

```sh
~/Apps/GIMP/runner
```

The first run links `~/.config/GIMP` to `~/Apps/GIMP/dat`, installs GIMP if needed, and launches the application. Drop a `gimp.desktop` and an icon in the folder to add desktop integration.

The reference template uses `PKG` as the command name. The target contract adds `BIN_NAMES` for packages whose command differs from the package name.

## How it decides

Precedence, highest first:

1. **Explicit header values** — `DAT_SOURCE`, `DAT_TARGET`, `BIN_SOURCE`, `BIN_TARGET`.
2. **Contents** — symlinks in `bin/` mean host-owned binaries; real files mean folder-owned binaries; a directory with `config`, `data`, `state`, or `cache` subdirectories is data.
3. **Name assumptions** — `dat`, `data`, `dados`, `bin`, `binaries`, and friends, configurable with `LANG_INFERRING_*`.
4. **Defaults** — no `bin/` means run from `PATH`; no data target means no data redirection.

Detection never deletes a real file. Ambiguous layouts abort and print the candidates instead of guessing.

## Package manager abstraction

`PACKAGE_MANAGER` decides how missing binaries are obtained. The default chain is:

1. `pkgcli` — PackageKit-based, preferred when installed.
2. `pkcon` — older PackageKit CLI; not present everywhere.
3. native — `apt`/`apt-get` on Debian/Ubuntu, `dnf` on Fedora, `pacman` then `yay` on Arch, `zypper` on openSUSE.

`PACKAGE_MANAGER="auto"` (the default) walks that chain. `native` is an alias. `distro` forces the distro manager only. `flatpak` uses `FLATPAK_ID`. `none` disables installation.

The runner checks `BIN_NAMES` first. If a command is missing, it installs `PKG`. If `PKG` is empty or the package name is unknown, it searches the backend and installs an exact match; several matches abort and print the candidates. It never replaces a working host binary.

## Methods

Everything is one primitive:

```text
redirect <portable> <host> <method>
```

| Method | Direction | Needs | Use when |
|---|---|---|---|
| `link` | host → portable | nothing | default; the app accepts symlinks |
| `link-out` | portable → host | nothing | the folder should reference host data |
| `env` | none | the app respects the variable | XDG-aware apps and app-specific variables |
| `bind` | either | root + lifecycle | the app replaces symlinks; last resort |
| `none` | none | nothing | leave the host path alone |

`link` is the default. `env` is the clean fallback for apps that respect `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, or their own variable. `bind` is specified but not implemented: it needs a mount/unmount lifecycle and does not survive a reboot.

Binaries have their own modes: `in` (portable links to host binaries), `out` (real binaries in the folder, links on the host), `copy` (real binaries, no host links), and host mode (no `bin/`, run from `PATH`). Host-provided is the default and the recommended mode; folder-owned is opt-in.

## XDG overrides

`XDG_CONFIG_HOME` is a **base directory**, not an application directory. Set it to the portable base and let the app append its own name:

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat/config"
DAT_METHOD="env"
DAT_ENV="XDG_CONFIG_HOME"
```

The app writes to `$PORTABLE_ROOT/dat/config/firefox/…`. Setting the variable to `…/config/firefox` produces `…/config/firefox/firefox/`.

For a specific path, use `link`:

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat/GIMP"
DAT_TARGET="$HOME/.config/GIMP"
DAT_METHOD="link"
```

Do not override `HOME` by default. It redirects everything, including dotfiles, and breaks absolute paths.

## Desktop integration

Drop an image and a `.desktop` file in the portable root:

```text
MyApp/
├── runner
├── icon.svg
└── MyApp.desktop
```

The runner links the desktop file into `~/.local/share/applications`, rewrites `Exec=` to the runner, rewrites `Icon=` to the absolute portable path, and sets the folder icon through `gio` when available. Remove the files to opt out.

## Safety

The target engine enforces these rules. The reference template implements an earlier subset and does not yet meet all of them.

- Existing host data is moved into the portable folder on first link; a real conflict is rotated to `.1`, `.2`, and so on, never overwritten.
- A real file or directory is never replaced by a symlink unless the backup succeeds. Root-owned targets use `sudo` for the backup too.
- Cleanup only touches links whose name and target belong to this runner. No broad `rm "$BIN_TARGET"/*`.
- Every run is idempotent.
- `UPAL_DRY_RUN=1` prints the planned actions and changes nothing. `UPAL_VERBOSE=1` prints detection results.
- The filesystem check runs once, on the portable root, and exits cleanly. It does not kill the terminal from a subshell.
- Paths with spaces and non-ASCII names are quoted everywhere.

## Status

| Area | State |
|---|---|
| Single-file POSIX runner | implemented |
| Data link (host → portable) | implemented |
| Binary link-out | implemented |
| Binary link-in | specified |
| `env` and `link-out` data methods | specified |
| Auto-detection of `bin` and `dat` | specified |
| Package manager chain (`pkgcli` > `pkcon` > native) | partially implemented; search and `yay` fallback specified |
| `bind` method | deferred |
| Rust engine | future |
| Windows support | future, native binary only |
| macOS `.app` bundles | non-goal |

The reference implementation is `posix_variables`. The full target contract is in [docs/configuration.md](docs/configuration.md).

## Documentation

- [Configuration reference](docs/configuration.md) — every header variable, method, and detection rule.
- [Design](docs/design.md) — architecture, the single-file rule, platforms, non-goals.
- [Examples](docs/examples.md) — GIMP, Firefox, adb, minimal, self-contained.

## Non-goals

- macOS `.app` bundles. They are metadata-driven and conflict with the no-metadata rule; the current engine is POSIX/Linux.
- Windows registry emulation. Windows support means a native binary that understands `%APPDATA%` and `%LOCALAPPDATA%`.
- A config file or a daemon. The runner is the config.
- Bundling every library. Host-provided binaries are the default; the folder owns data and identity.

## License

No license has been chosen yet. Treat the repository as all rights reserved until one is added.
