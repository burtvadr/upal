# Configuration reference

The runner is one file. The header at the top is the configuration; the rest is the engine. Explicit values win; empty values trigger detection.

Data is the primary use case. Binaries are replaceable; the data mapping is the part that must survive. Host-provided binaries are the default, and folder-owned binaries are opt-in.

> The reference template (`posix_variables`) implements the `link` and binary `out` subset today. The `env`, `link-out`, `bind`, and auto-detection rules below are the target contract.

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
| `PACKAGE_MANAGER` | `auto` | `auto`/`native` (PackageKit chain), `distro` (native only), `flatpak`, or `none`. |
| `FLATPAK_ID` | `""` | Flatpak application ID, when the package is a Flatpak. |
| `BIN_NAMES` | `""` | Commands to check, link, and run. Empty means the words in `PKG`, or the runner filename. |
| `DAT_SOURCE` | `""` | Portable data directory. Empty means detect; if `DAT_TARGET` is set, defaults to `$PORTABLE_ROOT/dat`. |
| `DAT_TARGET` | `""` | Host data path. Empty means XDG mapping when the data directory is XDG-shaped, otherwise no redirection. |
| `DAT_METHOD` | `link` | `link`, `link-out`, `env`, `bind`, or `none`. |
| `DAT_ENV` | `XDG_CONFIG_HOME` | Variable exported for the `env` method. |
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

## Package manager

`PACKAGE_MANAGER` controls how missing commands are obtained.

| Value | Behavior |
|---|---|
| `auto` / `native` | `pkgcli` > `pkcon` > native |
| `distro` | native package manager only |
| `flatpak` | `flatpak install` and `flatpak run` with `FLATPAK_ID` |
| `none` | never install |

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
}

app_post_link() {
    sed -i "s|^Icon=.*|Icon=$ICON_SOURCE/sndcpy.svg|" \
        "$DESKTOP_FILE_SOURCE/sndcpy.desktop"
}
```

- `app_env` runs before the application starts.
- `app_pre_link` runs before symlinks are changed.
- `app_post_link` runs after desktop and icon integration.

## Environment

| Variable | Effect |
|---|---|
| `UPAL_DRY_RUN=1` | Print planned actions, change nothing, exit 0. |
| `UPAL_VERBOSE=1` | Print detection results and actions. |

Environment variables are used instead of CLI flags so application arguments from `%U` and `%F` pass through untouched.

## Safety rules

1. Never replace a real file or directory without a successful backup. Back up with `sudo` when the target is root-owned; abort if the backup fails.
2. Only touch links whose name is managed and whose target belongs to this runner. No broad globs.
3. Rotate conflicts to `.1`, `.2`, and so on; never overwrite.
4. Every run is idempotent.
5. Switching modes never deletes real binaries. `out` → `in` aborts if real files occupy the link paths.
6. The filesystem check runs once on `$PORTABLE_ROOT` and exits cleanly. NTFS, exFAT, and similar filesystems are refused.
7. Quote every path. Use `--` for commands that accept it.
8. Do not run the same portable folder twice at the same time, and do not move it while the application is running.
