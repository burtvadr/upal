# Configuration reference

The runner is one file. The header at the top is the configuration; the rest is the engine. Explicit values win; empty values trigger detection.

Data is the primary use case. Binaries are replaceable; the data mapping is the part that must survive. Host-provided binaries are the default, and folder-owned binaries are opt-in.

> The reference template (`posix_variables`) implements the `link`, binary `out`, and icon subset today. The `env`, `link-out`, `bind`, and bin/dat auto-detection rules below are the target contract.

## Header

```sh
#!/bin/sh
# POSIX generic portable application script

# Directory where this script lives
SELF=$(readlink -f -- "$0" 2>/dev/null) || SELF=$0
PORTABLE_ROOT=$(cd -P -- "$(dirname -- "$SELF")" && command pwd -P)

# Variables
PKG=""
PACKAGE_MANAGER="auto"
FLATPAK_ID=""
BIN_NAMES=""
DAT_SOURCE=""
DAT_TARGET=""
DAT_METHOD="link"
DAT_ENV="XDG_CONFIG_HOME"
BACKUP="yes"
BIN_MODE="auto"
BIN_SOURCE=""
BIN_TARGET=""
DESKTOP_FILE_SOURCE="$PORTABLE_ROOT"
DESKTOP_FILE_TARGET="$HOME/.local/share/applications"
DESKTOP_FILE_NAME=""
DESKTOP_INTEGRATION="yes"
ICON_SOURCE="$PORTABLE_ROOT"
ICON_TARGET=""
ICON_NAME=""
NAME="$PKG"
CACHE_SOURCE=""
CACHE_TARGET=""
CACHE_METHOD="link"
MAN="$BIN_SOURCE"
KILL_TERMINAL="yes"
```

`SELF` is resolved through `readlink -f` so a runner symlinked into `PATH` still finds its real root. Every path variable is quoted; spaces and non-ASCII names are supported.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `PKG` | `""` | Package or packages to install, space-separated. Empty means search for `BIN_NAMES`, or use the runner filename. |
| `PACKAGE_MANAGER` | `auto` | `auto`/`native` (PackageKit chain), `distro`, `flatpak`, `snap`, `nix`, `brew`, `toolpak`, `pkgit`, `cpak`, or `none`. |
| `FLATPAK_ID` | `""` | Flatpak application ID. Required by the Flatpak profile; the data path is derived. |
| `BIN_NAMES` | `""` | Commands to check, link, and run. Empty means the words in `PKG`, or the runner filename. |
| `DAT_SOURCE` | `""` | Portable data directory. Empty means detect; if `DAT_TARGET` is set, defaults to `$PORTABLE_ROOT/dat`. |
| `DAT_TARGET` | `""` | Host data path. Empty means XDG mapping when the data directory is XDG-shaped, otherwise no redirection. |
| `DAT_METHOD` | `link` | `link`, `link-out`, `env`, `bind`, or `none`. |
| `DAT_ENV` | `XDG_CONFIG_HOME` | Variable exported for the `env` method. |
| `BACKUP` | `yes` | Before replacing an existing host path, keep it as `<path>.bak`, then `.bak.1`, `.bak.2`. `no` aborts on conflict. |
| `BIN_MODE` | `auto` | `auto`, `in`, `out`, or `copy`. |
| `BIN_SOURCE` | `""` | Portable binary directory or single file. Empty means detect. |
| `BIN_TARGET` | `""` | Host `PATH` directory or single file. Used by `out` only. Empty means the first writable `PATH` directory. |
| `DESKTOP_FILE_SOURCE` | `$PORTABLE_ROOT` | Where to find `*.desktop` files. |
| `DESKTOP_FILE_TARGET` | `$HOME/.local/share/applications` | Where to link them. |
| `DESKTOP_FILE_NAME` | `""` | Optional filter. Empty means all `*.desktop` files in the source. |
| `DESKTOP_INTEGRATION` | `yes` | Link and rewrite desktop files. |
| `ICON_SOURCE` | `$PORTABLE_ROOT` | Where to find the icon. |
| `ICON_TARGET` | `""` | Optional install path. Empty means the desktop file uses the absolute portable path. |
| `ICON_NAME` | `""` | Icon filename. Empty means the first image found in `ICON_SOURCE`. |
| `NAME` | `$PKG` | Display name. |
| `CACHE_SOURCE` | `""` | Portable cache directory. Off by default. |
| `CACHE_TARGET` | `""` | Host cache path. |
| `CACHE_METHOD` | `link` | Same methods as `DAT_METHOD`. |
| `MAN` | `$BIN_SOURCE` | Directory containing `*.1` man pages. Empty disables man linking. |
| `KILL_TERMINAL` | `yes` | Close the terminal that launched the runner after the app starts. |

## Data reuse and version compatibility

Portable data is independent of the binary. The same folder can point at a distro package, a Flatpak, or a locally built binary.

UPAL does not convert data between application versions or distributions. A profile written by a newer Arch package may not load in an older Debian package; that is the user's decision. The safety net is `BACKUP="yes"`: before a host path is replaced, the existing data is kept as `<path>.bak`. Disable it only when you have your own backup.

## Methods

The engine has one primitive:

```text
redirect <portable> <host> <method>
```

### `link`

The host path becomes a symlink to the portable path.

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat/GIMP"
DAT_TARGET="$HOME/.config/GIMP"
DAT_METHOD="link"
```

```text
~/.config/GIMP -> ~/Apps/GIMP/dat/GIMP
```

This is the default. It works for any application that accepts a symlinked directory. Some applications replace the symlink or resolve it to a real path; use `env` or `bind` for those.

If the host path already exists, it is backed up as `<path>.bak` before the link. Further conflicts use `.bak.1`, `.bak.2`, and so on. `BACKUP="no"` aborts instead of overwriting.

### `link-out`

The portable path becomes a symlink to the host path.

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat/GIMP"
DAT_TARGET="$HOME/.config/GIMP"
DAT_METHOD="link-out"
```

```text
~/Apps/GIMP/dat/GIMP -> ~/.config/GIMP
```

This is a reference mode, not a portable mode: the folder now depends on host data. Use it to share data between a portable runner and a host install, or to migrate back to the host. It is never the default.

### `env`

The host path is untouched. The engine exports one variable for the application process.

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat/config"
DAT_METHOD="env"
DAT_ENV="XDG_CONFIG_HOME"
```

```text
XDG_CONFIG_HOME=~/Apps/GIMP/dat/config firefox
```

`XDG_CONFIG_HOME` is a base directory. The app appends its own name, so the result is `…/dat/config/firefox/…`. Setting it to `…/dat/config/firefox` produces `…/dat/config/firefox/firefox/…`.

For app-specific variables, set `DAT_ENV`:

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat"
DAT_METHOD="env"
DAT_ENV="GIMP2_DIRECTORY"
```

For more than one variable, use the `app_env` hook.

### `bind`

Mounts the host path and the portable path together.

```sh
DAT_METHOD="bind"
```

Not implemented. It needs root, a mount/unmount lifecycle, and does not survive a reboot. It is the last resort for applications that replace symlinks.

### `none`

Leaves the host path alone. Use it to document a decision, or to disable a mapping inherited from a template.

## Binary modes

| Mode | Portable `bin/` | Host `BIN_TARGET` | sudo |
|---|---|---|---|
| `in` | symlinks to host binaries | untouched | no |
| `out` | real binaries | symlinks to the portable folder | only for root-owned targets |
| `copy` | real binaries | untouched | no |
| host | absent | untouched | no |

Host-provided (`in`, or host mode with no `bin/`) is the default. `out` and `copy` are for offline use, a self-contained folder, or a locally compiled binary. Data portability does not depend on any of them.

`auto` inspects the contents:

- symlinks in `bin/` → `in`;
- real executable files in `bin/` → `out`;
- empty `bin/` → `in`;
- no `bin/`, but executables at the root → `out` or `in`, by contents;
- no binaries at all → host mode.

`bin/` wins when both `bin/` and root executables exist. The runner itself is excluded from detection by its real path. Naming the runner the same as an application binary is an error.

Examples:

```sh
# Host-owned binaries, no sudo, updates flow through
BIN_MODE="in"
BIN_SOURCE="$PORTABLE_ROOT/bin"
```

```text
bin/gimp -> /usr/bin/gimp
```

```sh
# Folder-owned binaries, exposed on the host
BIN_MODE="out"
BIN_SOURCE="$PORTABLE_ROOT/bin"
BIN_TARGET=""
```

```text
bin/gimp (real)
~/.local/bin/gimp -> ~/Apps/GIMP/bin/gimp
```

```sh
# Folder-owned binaries, no host changes
BIN_MODE="copy"
BIN_SOURCE="$PORTABLE_ROOT/bin"
```

## Backends

`PACKAGE_MANAGER` selects the backend. Support means the runner owns the install and run logic for that backend; there is no universal package API.

| Value | Install | Run |
|---|---|---|
| `auto` / `native` | `pkgcli` > `pkcon` > native | command on `PATH` |
| `distro` | native package manager only | command on `PATH` |
| `flatpak` | `flatpak install` | `flatpak run "$FLATPAK_ID"` |
| `snap` | `snap install` | `snap run "$PKG"` |
| `nix` | `nix profile install nixpkgs#<pkg>` | `nix run nixpkgs#<pkg>` |
| `brew` | `brew install` | command on `PATH` |
| `toolpak` | adapter-defined | adapter-defined |
| `pkgit` | adapter-defined, source build | built binary |
| `cpak` | `cpak install <source>` | `cpak run <pkg>` |
| `none` | never | command on `PATH` |

Toolpak and pkgit are adapter-defined: the runner needs their install and run commands and does not assume a CLI. cpak is an OCI application package format: `cpak install` takes a source such as `github.com/owner/repo`, and `cpak run` takes the package and an optional command. When the backend is not a package manager, use `app_install` and `app_run` to own the steps.

Native mapping:

| Distro | Command |
|---|---|
| Debian/Ubuntu | `apt-get` (or `apt`) |
| Fedora | `dnf` |
| Arch | `pacman`, then `yay` for AUR |
| openSUSE | `zypper` |

The runner checks `BIN_NAMES` first. If every command exists, no install happens. If one is missing, it installs the corresponding word from `PKG`. If `PKG` is empty, it searches the backend for the command name and installs an exact match. Several matches abort and print the candidates; the runner never installs an ambiguous package.

Search commands used by the native fallback: `apt-cache search`, `dnf search`, `pacman -Ss`, `zypper search`. `pkgcli` and `pkcon` search first when available.

Packages are installed one per word, so `PKG="adb fastboot heimdall scrcpy"` loops over four packages. `BIN_NAMES` is separate because a package name and a command name often differ.

## Flatpak profile

`PACKAGE_MANAGER="flatpak"` is a profile: only `FLATPAK_ID` is required. The engine fills the standardized paths.

| Path | User install | System install |
|---|---|---|
| binaries | `~/.local/share/flatpak/app/$FLATPAK_ID` | `/var/lib/flatpak/app/$FLATPAK_ID` |
| data | `~/.var/app/$FLATPAK_ID` | `~/.var/app/$FLATPAK_ID` |
| desktop export | `~/.local/share/flatpak/exports/share/applications/$FLATPAK_ID.desktop` | `/var/lib/flatpak/exports/share/applications/$FLATPAK_ID.desktop` |

Derived values:

- `DAT_SOURCE="$PORTABLE_ROOT/dat"` if empty.
- `DAT_TARGET="$HOME/.var/app/$FLATPAK_ID"` if empty.
- `BIN_MODE` is host: no binary links; run with `flatpak run "$FLATPAK_ID"`.
- `PKG` is not used; install with `flatpak install`.
- Desktop entry and icon come from the Flatpak export when present.

```sh
PACKAGE_MANAGER="flatpak"
FLATPAK_ID="com.developer.App"
```

The data path is the same for user and system installs. Some applications write outside `~/.var/app/$FLATPAK_ID`; add those paths explicitly with the `redirect` helper in a hook. Heroic's `~/Games` is the common example.

## Detection

Precedence:

1. Explicit header values.
2. Contents.
3. Name assumptions (`LANG_INFERRING_BIN`, `LANG_INFERRING_DATA`).
4. Defaults, or a warning.

Rules:

- Search depth is at most two directories.
- `$PORTABLE_ROOT/bin/dat` and `$PORTABLE_ROOT/dat/bin` are invalid: one role cannot live inside the other.
- If several candidates match, abort and print them. Do not guess.
- If `DAT_TARGET` is set and `DAT_SOURCE` is empty, create `$PORTABLE_ROOT/dat`.
- If `DAT_SOURCE` is set and `DAT_TARGET` is empty, use XDG mapping only when the source has `config`, `data`, `state`, or `cache` subdirectories. Otherwise warn and skip.
- If neither is set, do not redirect data.
- Detection never deletes a real file or directory.

## Hooks

The app-specific block sits between the header and the engine. It survives template updates.

```sh
app_env() {
    export MOZ_LEGACY_PROFILES=1
}

app_pre_link() {
    adb kill-server
    redirect "$PORTABLE_ROOT/games" "$HOME/Games" link
}

app_post_link() {
    sed -i "s|^Icon=.*|Icon=$ICON_SOURCE/sndcpy.svg|" \
        "$DESKTOP_FILE_SOURCE/sndcpy.desktop"
}
```

For a stack or an adapter, the install and launch steps replace the package command:

```sh
app_install() {
    docker compose pull
}

app_run() {
    docker compose up -d
    xdg-open "http://localhost:2283"
}
```

- `app_env` runs before the application starts.
- `app_pre_link` runs before symlinks are changed.
- `app_post_link` runs after desktop and icon integration.
- `app_install` replaces the backend install step. Use it for stacks and adapters.
- `app_run` replaces the default launch. It receives the original arguments; use it for container stacks such as Immich.
- `redirect <portable> <host> <method>` is available to hooks for extra paths, such as Heroic's `~/Games`. The header stays one mapping per role; the hook handles the exceptions.

## Icons

Any image at the portable root, or in `ICON_SOURCE`, is a candidate. The first one becomes the desktop and folder icon; `ICON_NAME` pins a specific file. Detection uses the MIME type, not the extension, so a PNG named `icon.svg` still works.

- `ICON_TARGET` optionally installs the image into an icon theme directory. Empty means the desktop entry points at the absolute portable path.
- `gio` sets `metadata::custom-icon` on the portable root and on `DAT_TARGET`.
- Deleting the image resets both: the folder icon is unset with `gio set -t unset`, and the desktop `Icon=` falls back to the package or application name. The next run restores the image icon if a new image appears.

## Environment

| Variable | Effect |
|---|---|
| `UPAL_DRY_RUN=1` | Print planned actions, change nothing, exit 0. |
| `UPAL_VERBOSE=1` | Print detection results and actions. |

Environment variables are used instead of CLI flags so application arguments from `%U` and `%F` pass through untouched.

## Safety rules

1. Never replace a real file or directory without a successful backup. Back up with `sudo` when the target is root-owned; abort if the backup fails.
2. Only touch links whose name is managed and whose target belongs to this runner. No broad globs.
3. Back up conflicts as `.bak`, `.bak.1`, `.bak.2`, and so on; never overwrite. `BACKUP="yes"` is the default.
4. Every run is idempotent.
5. Switching modes never deletes real binaries. `out` → `in` aborts if real files occupy the link paths.
6. The filesystem check runs once on `$PORTABLE_ROOT` and exits cleanly. NTFS, exFAT, and similar filesystems are refused.
7. Quote every path. Use `--` for commands that accept it.
8. Do not run the same portable folder twice at the same time, and do not move it while the application is running.
