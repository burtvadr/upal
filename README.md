# upal

**Your app and everything it remembers, in one folder.**

UPAL is a portable app folder. It keeps the app, your settings, your saves, your plugins, and the rest of your data together. Move the folder to another drive or another PC, open it, and boom: the app is there with the work you left in it.

Think of it as a mix of a macOS app bundle and a Windows portable app:

- **Like a Mac app** — the folder is the app; click the runner and it opens.
- **Like a Windows portable app** — move it anywhere; your data comes with it.
- **Better than both** — the app itself can still come from your system package manager, so updates and security fixes keep flowing.

## What you get

- **One folder, not ten.** No more hunting through `~/.config`, `~/.local/share`, `~/.cache`, and `~/.var/app`.
- **One file to manage it.** The runner is the config, the engine, and the thing you click. A second manager file is not UPAL.
- **Move it and go.** Another disk, another machine, a backup: the data stays with the app.
- **Keep your package manager.** Flatpak, Snap, distro packages, Nix, Homebrew, and more.
- **Works with non-apps too.** A Docker Compose stack like Immich can live in the same kind of folder.
- **Looks like a real app.** Add an image and a desktop entry; the icon goes into your theme, so it keeps working when the folder moves.
- **No lock-in.** Your data stays as ordinary files.

## Data first, binaries disposable

The irreplaceable part is user data: profiles, saves, plugins, configuration, state. Binaries can be reinstalled or rebuilt. UPAL therefore defaults to host-provided binaries and treats folder-owned binaries as an optional mode.

- **Host-provided** (`in`, or host mode with no `bin/`) — the distro manages updates and security.
- **Folder-owned** (`out`, `copy`) — offline use, a self-contained folder, or a locally compiled build.
- **No binaries at all** — click and run; the package manager installs them.

A locally compiled application fits the same model: put the binary in `bin/`, set `BIN_MODE="copy"`, and keep the data mapping.

Portable data is independent of the binary. The same folder can point at a distro package, a Flatpak, or a locally built binary. UPAL does not convert data between application versions or distributions: moving an Arch profile to an older Debian build is the user's decision. `BACKUP="yes"` (default) keeps the previous host data as `<path>.bak` before linking, so there is a rollback.

The layout:

```text
MyApp/
├── runner          # the only manager file
├── bin/            # optional: links to host binaries, or real binaries
├── dat/            # optional: portable user data
├── icon.svg        # optional: first image becomes the icon
├── MyApp.desktop   # optional: desktop entry
└── application.json # optional: Nautilus bundle manifest
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

## Backends

`PACKAGE_MANAGER` selects the backend. Support means the runner owns the install and run logic for that backend; there is no universal package API.

| Backend | Value | Install | Run | Root |
|---|---|---|---|---|
| Native | `native` / `auto` | `pkgcli` > `pkcon` > `apt`/`dnf`/`pacman`+`yay`/`zypper` | command on `PATH` | yes |
| Distro only | `distro` | `apt`/`dnf`/`pacman`+`yay`/`zypper` | command on `PATH` | yes |
| Flatpak | `flatpak` | `flatpak install` | `flatpak run $FLATPAK_ID` | no (user) |
| Snap | `snap` | `snap install` | `snap run $PKG` | yes |
| Nix | `nix` | `nix profile install` | `nix run` | no |
| Homebrew | `brew` | `brew install` | command on `PATH` | no |
| Toolpak | `toolpak` | adapter | adapter | adapter |
| pkgit | `pkgit` | adapter, source build | built binary | adapter |
| cpak | `cpak` | `cpak install <source>` | `cpak run <pkg>` | adapter |
| None | `none` | never | command on `PATH` | no |

`auto`/`native` walks `pkgcli` > `pkcon` > native. `distro` forces the distro manager only. The Flatpak profile derives its paths from `FLATPAK_ID`. Toolpak and pkgit are adapter-defined: the runner needs their install and run commands and does not assume a CLI. cpak is an OCI application package format: `cpak install` takes a source, `cpak run` takes the package.

The runner never calls `sudo`. When a step needs root and it is not root, it stops and prints `Re-run as root: sudo ./runner`. Flatpak user installs and user-local links never need root.

The runner checks `BIN_NAMES` first. If a command is missing, it installs `PKG`. If `PKG` is empty or the package name is unknown, it searches the backend and installs an exact match; several matches abort and print the candidates. It never replaces a working host binary.

## Discovery tooling (planned)

A GTK tool will wrap `strace`/`ptrace` to observe which paths an application touches, group them by XDG role, and suggest `DAT_TARGET`, `DAT_METHOD`, and `BIN_MODE`. It is an authoring tool, not part of the runner: ptrace permissions, Flatpak sandboxes, and filesystem noise make it unsuitable for launch-time decisions. The runner keeps explicit configuration plus detection.

## Flatpak profile

Flatpak is the cleanest case because the paths are standardized. `PACKAGE_MANAGER="flatpak"` is a profile: it fills the paths from `FLATPAK_ID`, so there are no directories to configure.

| What | User install | System install |
|---|---|---|
| binaries | `~/.local/share/flatpak/app/$FLATPAK_ID` | `/var/lib/flatpak/app/$FLATPAK_ID` |
| data | `~/.var/app/$FLATPAK_ID` | `~/.var/app/$FLATPAK_ID` |

```sh
PACKAGE_MANAGER="flatpak"
FLATPAK_ID="com.developer.App"
```

The runner derives:

- `DAT_SOURCE="$PORTABLE_ROOT/dat"`;
- `DAT_TARGET="$HOME/.var/app/$FLATPAK_ID"`;
- install via `flatpak install`;
- run via `flatpak run "$FLATPAK_ID"`, with no binary links;
- desktop entry and icon from the Flatpak export, when present.

User and system installs differ only in where the binaries live; the data path is always `~/.var/app/$FLATPAK_ID`. User installs never need root. Some applications write outside the sandbox data directory: Heroic creates `~/Games`. Add it explicitly if you want it portable; it is not automatic.

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
| `copy` | portable → host | nothing | a one-time snapshot; no link |
| `copy-sync` | both, at launch | `rsync` | the app refuses links and approximate sync is acceptable |
| `bind` | either | root + lifecycle | the app replaces symlinks; last resort |
| `none` | none | nothing | leave the host path alone |

`link` is the default. `env` is the clean fallback for apps that respect `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, or their own variable. `bind` is specified but not implemented: it needs a mount/unmount lifecycle and does not survive a reboot.

`copy` copies the portable data to the host location once. Existing host data is backed up as `.bak` first. After that the two copies are independent: later changes on either side are not reconciled. Use it for a fixed configuration, an import, or an app that refuses links but does not need to write back.

`copy-sync` is the two-way hack. At launch it rsyncs host changes back into the portable folder, then copies the portable folder to the host before the app starts. It is approximate, can be outdated, does not resolve conflicts, and does not delete by default. It is the least reliable method; use it only when `link` and `env` do not work.

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

Any image at the root, or in `ICON_SOURCE`, becomes the icon; MIME type decides, not the extension. `ICON_NAME` pins a specific file. The runner links the desktop file into `~/.local/share/applications`, rewrites `Exec=` to the runner, installs the icon into the hicolor theme, and sets `Icon=<id>` so the desktop entry survives moving the folder. Standard field codes like `%U` and `%F` are kept; other host-specific arguments are dropped. Set `DESKTOP_REWRITE_EXEC="no"` for a suite where each entry launches a different tool. `ICON_ID` defaults to the icon filename without its extension; set a reverse-DNS name to avoid collisions. `ICON_METHOD` chooses `copy` (default), `link`, or `none`. The runner also sets the folder icon through `gio`. Delete the image and the next run removes the theme icon, resets the folder icon, and falls back the desktop entry to the default. Remove the desktop file to opt out.

## Multi-entry suites

A folder can hold several launchers. List them in `ENTRIES`; the engine wires each desktop entry, icon, and launch. This is how one folder keeps Blender LTS, latest, and experimental together without a second script. See the Blender example in [docs/examples.md](docs/examples.md).

## Nautilus bundles (planned)

The goal is to double-click the folder and launch the app, like a macOS bundle. Nautilus has no public hook for replacing directory activation, so this needs a small Nautilus patch. The plan is opt-in: a directory with an explicit `application.json` manifest is an application bundle; normal directories keep opening normally; downloaded bundles need confirmation before their first launch. Prototype in a Nautilus fork, then propose it upstream.

## Non-app stacks

The same folder can wrap a stack that is not a single binary. Immich is a Docker Compose project: the folder holds `docker-compose.yml`, `library/`, `postgres/`, and `run/`, and `app_run` starts it. Relative paths in the compose file mean moving the folder moves the data. One manager file remains the entry point; the helper scripts are part of the stack.

The runner does not learn Docker. `app_install` and `app_run` are hooks for backends and stacks whose install or launch is not a package command.

## Packaging (future)

A portable folder can be zipped into one file for transport. Unzip it, click the runner. AppManager interoperability is a possible opt-in integration, only if both projects are ready. See [packaging.md](docs/packaging.md).

## Safety

The target engine enforces these rules. The reference template implements an earlier subset and does not yet meet all of them.

- Existing host data is moved into the portable folder on first link; a real conflict is backed up as `.bak`, `.bak.1`, `.bak.2`, never overwritten. Backup is on by default (`BACKUP="yes"`).
- A real file or directory is never replaced by a symlink unless the backup succeeds. If a target needs root, the runner stops and asks you to re-run it with sudo; it never invokes sudo itself.
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
| `copy` and `copy-sync` data methods | specified |
| Auto-detection of `bin` and `dat` | specified |
| Package manager chain (`pkgcli` > `pkcon` > native) | partially implemented; search and `yay` fallback specified |
| No internal sudo; root check and message | implemented |
| Flatpak profile (auto paths) | specified |
| Snap, Nix, Homebrew, Toolpak, pkgit, cpak adapters | specified |
| Icon auto-detect, theme install, and reset | implemented |
| Desktop entry link and `Exec=` rewrite | implemented |
| Multi-entry suites (`ENTRIES`) | implemented |
| Discovery GUI (`strace`/`ptrace`) | planned |
| Nautilus directory activation (opt-in bundles) | planned |
| Portable ZIP archive and AppManager interoperability | idea |
| `.bak` before replacing host data | implemented |
| `app_install` / `app_run` hooks, non-app stacks | specified |
| `bind` method | deferred |
| Rust engine | future |
| Windows support | future, native binary only |
| macOS `.app` bundles | non-goal |

The reference implementation is `posix_variables`. The full target contract is in [docs/configuration.md](docs/configuration.md).

## Documentation

- [Configuration reference](docs/configuration.md) — every header variable, method, and detection rule.
- [Design](docs/design.md) — architecture, the single-file rule, platforms, non-goals.
- [Nautilus bundles](docs/nautilus.md) — the opt-in directory activation plan and implementation routes.
- [Packaging](docs/packaging.md) — ZIP transport, safe unpacking, and the AppManager idea.
- [Examples](docs/examples.md) — GIMP, Firefox, adb, Immich, minimal, self-contained.

## Non-goals

- macOS `.app` bundles as a format. The Linux equivalent is the opt-in Nautilus bundle above, not a macOS bundle.
- Windows registry emulation. Windows support means a native binary that understands `%APPDATA%` and `%LOCALAPPDATA%`.
- Data conversion between application versions or distributions. The user owns that decision; UPAL backs up.
- A config file or a daemon for the runner. The runner is the config; the Nautilus manifest is optional desktop integration.
- Bundling every library. Host-provided binaries are the default; the folder owns data and identity.

## License

No license has been chosen yet. Treat the repository as all rights reserved until one is added.
