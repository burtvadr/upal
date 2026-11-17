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

Portable data is independent of the binary. The same folder can point at a distro package, a Flatpak, or a locally built binary. UPAL does not convert data between application versions or distributions: moving an Arch profile to an older Debian build is the user's decision. `BACKUP="yes"` (default) copies existing host data into the portable folder and keeps the host copy as `<path>.bak`, so there is a rollback.

The layout:

```text
MyApp/
├── runner          # the only manager file
├── bin/            # optional: links to host binaries, or real binaries
├── dat/            # optional: portable user data
├── icon.svg        # optional: single image becomes the icon
├── MyApp.desktop   # optional: desktop entry
└── application.json # optional: Nautilus bundle manifest
```

The runner resolves its own location, so the folder can be renamed or moved. The directory names are language assumptions, not requirements: the header can point anywhere, and an empty source is inferred from `LANG_INFERRING_DATA` or `LANG_INFERRING_BIN`.

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

The header decides. An empty source triggers name inference:

1. **Explicit values** — `DAT_SOURCE`, `DAT_TARGET`, `BIN_SOURCE`, `BIN_TARGET`, `CMD_TARGET`. Naming a source disables inference for that side.
2. **Name lists** — `LANG_INFERRING_DATA` and `LANG_INFERRING_BIN` are checked at the portable root first, then one level below. A root-level match wins; several at the same depth abort with the candidates; none leaves that side off. Contents are never inspected.
3. **Flatpak** — `DAT_TARGET` defaults to `~/.var/app/$FLATPAK_ID` when a data source exists.
4. **No side** — no binary source means no binary mapping; the app runs from `PATH` or `flatpak run`. No data target means no redirection.

The defaults are `dat data dados config user` for data and `bin binary binaries binarios executables executável executáveis executaveis executavel` for binaries. Edit the lists to add your own language or layout, or empty a list to disable that inference.

Once a managed source exists, its device, inode, and top-level names and types are remembered under `${XDG_STATE_HOME:-$HOME/.local/state}/upal/`. The state key is the portable root's device and inode, so renaming the root on the same filesystem keeps the recovery history. If an explicit `DAT_SOURCE`, `BIN_SOURCE`, or a custom `DESKTOP_FILE_SOURCE` disappears, the next run searches for it before linking or launching. An exact inode match wins. Otherwise at least two top-level entries must match, with 65% confidence and a 15-point lead over the next candidate. A confident match updates the source path and repairs the links. No match, or a tie, stops the run and prints the closest candidates. A broken target link is removed first, but no empty source directory is created when the source was known before; a target that still points to real data is left alone and the run stops. A first run may still create `DAT_SOURCE` to adopt existing host data. The state stays outside the portable folder; remove `source-<key>-<role>` to start fresh.

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

The runner checks whether `PKG` is already on `PATH`; if not, it installs `PKG` with the selected backend. The backend search fallback and the exact-match rule are target contract.

## Discovery tooling (planned)

A GTK tool will wrap `strace`/`ptrace` to observe which paths an application touches, group them by XDG role, and suggest `DAT_TARGET`, `DAT_METHOD`, and `BIN_MODE`. It is an authoring tool, not part of the runner: ptrace permissions, Flatpak sandboxes, and filesystem noise make it unsuitable for launch-time decisions. The runner keeps explicit configuration, with name inference only when a source is empty.

## Flatpak profile

Flatpak is the cleanest case because the app ID fills the standard paths. Create `dat/` to make data portable, `bin/` to reference the app's binaries, or both. No `DAT_TARGET` or `BIN_TARGET` is needed.

```text
MyApp/
├── runner
├── dat/            # optional: portable ~/.var/app/$FLATPAK_ID
└── bin/            # optional: reference to the app's binaries
```

```sh
FLATPAK_ID="com.developer.App"
FLATPAK_SCOPE="user"   # or "system"
FLATPAK_OFFLOAD=""     # optional: names under the deployment's files/
```

The runner:

- checks for `flatpak`; if missing, tries `pkgcli`, then `pkcon`, then the distro package manager;
- adds the flathub remote when it is missing, using `FLATPAK_SCOPE`;
- asks for a reboot after installing flatpak itself, then exits so the next run starts cleanly;
- installs the app with `flatpak install --user|--system -y flathub` when it is missing;
- runs with `flatpak run --user|--system "$FLATPAK_ID"`;
- if a data source exists, links `~/.var/app/$FLATPAK_ID` to it;
- if the binary source is a symlink, uses it as-is; point it at the active deployment's `files/bin` (or `files`) to expose the binaries without generated files;
- if the binary source is a real directory, creates `$BIN_SOURCE/$FLATPAK_ID` as a read-only reference to the active deployment's `files/bin` (or `files`); the link uses `active`, so it follows Flatpak updates;
- if no portable icon is present, uses the Flatpak app's exported icon for the portable root, the data target, and `BIN_TARGET` when set, through `gio`;
- if `FLATPAK_OFFLOAD` is set, moves the named entries from the active deployment's `files/` into `BIN_SOURCE`, symlinks them back, and adds a read-only filesystem override for `BIN_SOURCE`;
- never links the app or arch installation directories;
- leaves host data alone when no data source is present;
- creates no binary reference when no binary source is present, and does not treat a deleted binary source as a renamed one;
- generates no launcher; `run` is the launcher and calls `flatpak run`.
- uses Flatpak's exported desktop entry and icon; a portable `.desktop` or icon is optional.

`PACKAGE_MANAGER` may be omitted; setting `FLATPAK_ID` selects the Flatpak profile when the manager is `auto`. `FLATPAK_SCOPE` defaults to `user`; `system` uses the system-wide installation and may require administrator authentication.

```text
~/.var/app/com.developer.App -> ~/Apps/MyApp/dat
~/Apps/MyApp/bin -> ~/.local/share/flatpak/app/com.developer.App/$ARCH/stable/active/files/bin
```

The data path is the same for user and system installs. `bin/` is optional and has two forms: a symlink to the active deployment's `files/bin` (or `files`), or a real directory holding `bin/$FLATPAK_ID` as a read-only reference to the same deployment. Both follow the `active` path and leave the Flatpak installation untouched. No launcher is generated; `run` calls `flatpak run`. Flatpak does not support symlinking an individual app installation directory (`~/.local/share/flatpak/app/$FLATPAK_ID` or `/var/lib/flatpak/app/$FLATPAK_ID`); the runner never does that. Symlinking the arch directory (`.../app/$FLATPAK_ID/$ARCH`) is not a workaround either: Flatpak stops listing the app, and update/uninstall cannot find it. Symlinking the deployment's `files` directory itself is also not enough: listing and updates still work, but `flatpak run` fails in bwrap. Symlinking an entry **inside** `files` works when the target is exposed with a read-only filesystem override; `FLATPAK_OFFLOAD` does that automatically. It keeps `files` a real directory, so listing and updates still work, and the override lets the sandbox resolve the symlink. It is experimental, and the app installation must be writable (user scope no root; system scope root). On updates the previous target is kept as `<name>1`, `<name>2`; do not list `.ref`. To relocate the whole Flatpak installation, use a custom installation or `FLATPAK_USER_DIR`; a bind mount offloads one app without the override. The data directory `~/.var/app/$FLATPAK_ID` is separate, and Flatpak resolves a symlinked data directory (tested with Flatpak 1.16). Some applications write outside `~/.var/app/$FLATPAK_ID`: Heroic creates `~/Games`. Add those explicitly if you want them portable; they are not automatic.

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

Any single image at the root, or in `ICON_SOURCE`, becomes the icon; the MIME type decides the format, not the filename or extension, so renaming it to `banana` keeps working. Auto-detected icons use the package name as the theme ID, so a rename does not break the desktop entry; `ICON_ID` overrides it. `ICON_NAME` pins an exact file. If more than one image is present, the runner does not guess: it restores the default icon. The runner links the desktop file into `~/.local/share/applications`, rewrites `Exec=` to the runner, installs the icon into the hicolor theme, and sets `Icon=<id>` so the desktop entry survives moving the folder. Standard field codes like `%U` and `%F` are kept; other host-specific arguments are dropped. Set `DESKTOP_REWRITE_EXEC="no"` for a suite where each entry launches a different tool. Set a reverse-DNS `ICON_ID` to avoid collisions. `ICON_METHOD` chooses `copy` (default), `link`, or `none`. The runner also sets the folder icon through `gio`. Replacing the image archives the previous theme icon as `<id>.<ext>1`, then `2`, and so on; deleting the image restores the oldest archive, so the default icon returns without manual path management. A format change keeps the previous format as the default archive. For Flatpak, if the portable root has no image, the runner uses the app's exported icon (`Icon=` from the exported desktop file, falling back to `$FLATPAK_ID`) for the `gio` folder metadata on the root, `BIN_TARGET`, and the data target. Remove the desktop file to opt out.

## Multi-entry suites

A folder can hold several launchers. If `bin/` contains variant subdirectories, the engine detects them automatically; `ENTRIES` is the explicit override. Command links go to `CMD_TARGET`, a user PATH directory. If `BIN_TARGET` is set, each entry's executable is linked into `BIN_TARGET/<entry>/` and the command link points there; this avoids flattening variants into one app binary directory. See the configuration reference.

## Nautilus bundles (planned)

The goal is to double-click the folder and launch the app, like a macOS bundle. Nautilus has no public hook for replacing directory activation, so this needs a small Nautilus patch. The plan is opt-in: a directory with an explicit `application.json` manifest is an application bundle; normal directories keep opening normally; downloaded bundles need confirmation before their first launch. Prototype in a Nautilus fork, then propose it upstream.

## Non-app stacks

The same folder can wrap a stack that is not a single binary. Immich is a Docker Compose project: the folder holds `docker-compose.yml`, `library/`, `postgres/`, and `run/`, and `app_run` starts it. Relative paths in the compose file mean moving the folder moves the data. One manager file remains the entry point; the helper scripts are part of the stack.

The runner does not learn Docker. `app_install` and `app_run` are hooks for backends and stacks whose install or launch is not a package command.

## Packaging (future)

A portable folder can be zipped into one file for transport. Unzip it, click the runner. AppManager interoperability is a possible opt-in integration, only if both projects are ready. See [packaging.md](docs/packaging.md).

## Safety

The target engine enforces these rules. The reference template implements an earlier subset and does not yet meet all of them.

- Existing host data is copied into the portable folder on first link and the host copy is kept as `.bak`. A real conflict is backed up as `<path>1`, `<path>2`, and so on. Empty target directories are removed. Backup is on by default (`BACKUP="yes"`).
- A missing managed source is never replaced by an empty directory. The runner removes a broken target link, then tries inode and content matching; if it cannot identify the renamed directory with confidence, it stops.
- A broken link is removed with `rm -f` on the link itself. The destination is never followed or deleted, and no recursive delete is used.
- A real file or directory is never replaced by a symlink unless the backup succeeds. If a target needs root, the runner stops and asks you to re-run it with sudo; it never invokes sudo itself.
- Cleanup only touches links whose name and target belong to this runner. No broad `rm "$CMD_TARGET"/*`. A link that already resolves to the same inode is left untouched, even if it points through another path.
- Every run is idempotent.
- `UPAL_DRY_RUN=1` prints the planned actions and changes nothing. `UPAL_VERBOSE=1` prints recovered source paths.
- The filesystem check runs once, on the portable root, and exits cleanly. It does not kill the terminal from a subshell.
- Paths with spaces and non-ASCII names are quoted everywhere.

## Status

| Area | State |
|---|---|
| Single-file POSIX runner | implemented |
| Data link (host → portable) | implemented |
| Self-healing source relocation | implemented |
| Binary link-out | implemented |
| Binary link-in | specified |
| `env` and `link-out` data methods | specified |
| `copy` and `copy-sync` data methods | specified |
| Auto-detection of `bin` and `dat` | implemented (name-based) |
| Package manager chain (`pkgcli` > `pkcon` > native) | partially implemented; search and `yay` fallback specified |
| No internal sudo; root check and message | implemented |
| Flatpak profile (auto paths) | implemented |
| Snap, Nix, Homebrew, Toolpak, pkgit, cpak adapters | specified |
| Icon auto-detect, theme install, and reset | implemented |
| Desktop entry link and `Exec=` rewrite | implemented |
| Multi-entry suites (`ENTRIES`/auto-detect) | implemented |
| Discovery GUI (`strace`/`ptrace`) | planned |
| Nautilus directory activation (opt-in bundles) | planned |
| Portable ZIP archive and AppManager interoperability | idea |
| `.bak` before replacing host data | implemented |
| `app_install` / `app_run` hooks, non-app stacks | specified |
| `bind` method | deferred |
| Versioned header floor and canonical `upal` CLI | specified |
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

0BSD. See [LICENSE](LICENSE).
