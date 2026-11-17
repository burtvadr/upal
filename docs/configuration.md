# Configuration reference

The runner is one file. The header at the top is the configuration; the rest is the engine. Explicit values win. An empty `DAT_SOURCE` or `BIN_SOURCE` triggers name inference from `LANG_INFERRING_DATA` or `LANG_INFERRING_BIN`.

Data is the primary use case. Binaries are replaceable; the data mapping is the part that must survive. Host-provided binaries are the default, and folder-owned binaries are opt-in.

> The reference template (`posix_variables`) implements name-based source inference, `link`, binary `out`, icon, desktop-entry, and multi-entry handling today. The `env`, `link-out`, `copy`, `copy-sync`, and `bind` methods below are the target contract.

## Header

```sh
#!/bin/sh
# POSIX generic portable application script

# Directory where this script lives
PORTABLE_ROOT=$(cd -P -- "$(dirname -- "$0")" && command pwd -P)

# Variables
PACKAGE_MANAGER="auto"
FLATPAK_ID=""
FLATPAK_SCOPE="user"
FLATPAK_OFFLOAD=""
PKG=""
NAME="$PKG"
DAT_SOURCE=""
DAT_TARGET=""
BACKUP="yes"
BIN_SOURCE=""
LANG_INFERRING_DATA="dat data dados config user"
LANG_INFERRING_BIN="bin binary binaries binarios executables executável executáveis executaveis executavel"
BIN_TARGET=""
CMD_TARGET=""
DESKTOP_FILE_NAME=""
DESKTOP_FILE_SOURCE="$PORTABLE_ROOT"
DESKTOP_FILE_TARGET="$HOME/.local/share/applications"
DESKTOP_REWRITE_EXEC="yes"
# Multi-entry suites: name|bindir|executable|desktop|icon|icon_id
ENTRIES=""
DEFAULT_ENTRY=""
LAUNCHER=""
ICON_NAME=""
ICON_ID=""
ICON_SOURCE="$PORTABLE_ROOT"
ICON_TARGET=""
ICON_METHOD="copy"
ICON=""
CACHE_SOURCE=""
CACHE_TARGET=""
MAN="$BIN_SOURCE"
KILL_TERMINAL="yes"
```

`SELF` is set by the engine from `PORTABLE_ROOT` after the header. Every path variable is quoted; spaces and non-ASCII names are supported.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `PKG` | `""` | Package to install, or command to run when no binaries are linked. Empty means the runner only manages files. |
| `PACKAGE_MANAGER` | `auto` | `auto`/`native` (PackageKit chain), `distro`, `flatpak`, `snap`, `nix`, `brew`, `toolpak`, `pkgit`, `cpak`, or `none`. |
| `FLATPAK_ID` | `""` | Flatpak application ID. Setting it selects the Flatpak profile when `PACKAGE_MANAGER` is `auto`; a data or binary source selects the portable sides. |
| `FLATPAK_SCOPE` | `user` | `user` or `system`. Scope for the flathub remote, app install, and launch. User scope never needs root. |
| `FLATPAK_OFFLOAD` | `""` | Space-separated top-level entries under the active deployment's `files/` to move into `BIN_SOURCE`. Experimental; adds a read-only Flatpak filesystem override. Requires a real binary directory, not a symlink. |
| `DAT_SOURCE` | `""` | Portable data directory. Empty triggers name inference from `LANG_INFERRING_DATA`; an explicit value disables it. With `DAT_TARGET` set and no match, the first data word is created. |
| `DAT_TARGET` | `""` | Host data path. Empty means no redirection, except the Flatpak profile derives `~/.var/app/$FLATPAK_ID` when a data source exists. |
| `DAT_METHOD` | `link` | `link`, `link-out`, `env`, `copy`, `copy-sync`, `bind`, or `none`. |
| `DAT_ENV` | `XDG_CONFIG_HOME` | Variable exported for the `env` method. |
| `BACKUP` | `yes` | Adopted host data keeps a `<path>.bak` copy; a real conflict is kept as `<path>1`, `<path>2`. `no` aborts on conflict. |
| `BIN_MODE` | `auto` | `auto`, `in`, `out`, or `copy`. |
| `BIN_SOURCE` | `""` | Portable binary directory or single file. Empty triggers name inference from `LANG_INFERRING_BIN`; an explicit value disables it. |
| `LANG_INFERRING_DATA` | `dat data dados config user` | Words that name a data directory. Matched at the portable root and one level below. Several matches abort with the candidates. |
| `LANG_INFERRING_BIN` | `bin binary binaries binarios executables executável executáveis executaveis executavel` | Words that name a binary directory. Same matching rule. |
| `BIN_TARGET` | `""` | Host application binary directory or single file, for example `/opt/app-bin`. Used by `out` only. Empty disables binary-out linking. For multi-entry suites, each entry goes in its own `BIN_TARGET/<entry>/` directory. This is not a PATH directory; command links use `CMD_TARGET`. |
| `CMD_TARGET` | `""` | Directory for per-entry command symlinks. Empty auto-selects `~/.local/bin`, then `~/bin`, then `/usr/local/bin` or `/usr/bin`. Used only when `ENTRIES` is set. |
| `DESKTOP_FILE_SOURCE` | `$PORTABLE_ROOT` | Where to find `*.desktop` files. |
| `DESKTOP_FILE_TARGET` | `$HOME/.local/share/applications` | Where to link them. |
| `DESKTOP_FILE_NAME` | `""` | Optional filter. Empty means all `*.desktop` files in the source. |
| `DESKTOP_REWRITE_EXEC` | `yes` | Rewrite `Exec=` to the runner. Set `no` when the desktop files launch different tools from the same folder. |
| `ENTRIES` | `""` | Optional multi-entry list: `name\|bindir\|executable\|desktop\|icon\|icon_id` per line. |
| `DEFAULT_ENTRY` | `""` | Entry launched when no name is given. Empty means the first entry. |
| `LAUNCHER` | `""` | Optional external launcher/chooser. Runs when no entry name is given; bypassed by `run <entry>`. |
| `ICON_SOURCE` | `$PORTABLE_ROOT` | Where to find the icon. |
| `ICON_NAME` | `""` | Icon filename. Empty auto-detects a single image in `ICON_SOURCE`; pinning an exact name disables rename detection. |
| `ICON_ID` | derived | Theme icon name, without extension. Empty uses the package name for an auto-detected icon, or the `ICON_NAME` basename for a pinned file. |
| `ICON_TARGET` | derived | Theme directory. Empty means `~/.local/share/icons/hicolor/scalable/apps` for SVG, `256x256/apps` otherwise. |
| `ICON_METHOD` | `copy` | `copy`, `link`, or `none`. |
| `NAME` | `$PKG` | Display name. |
| `CACHE_SOURCE` | `""` | Portable cache directory. Off by default. |
| `CACHE_TARGET` | `""` | Host cache path. |
| `MAN` | `$BIN_SOURCE` | Directory containing `*.1` man pages. Empty follows `BIN_SOURCE`; with no binary source, man linking is off. |
| `KILL_TERMINAL` | `yes` | Close the terminal that launched the runner after the app starts. Ignored when the runner was not started from a terminal. |

## Data reuse and version compatibility

Portable data is independent of the binary. The same folder can point at a distro package, a Flatpak, or a locally built binary.

UPAL does not convert data between application versions or distributions. A profile written by a newer Arch package may not load in an older Debian package; that is the user's decision. The safety net is `BACKUP="yes"`: before a host path is replaced, the existing data is kept as `<path>.bak`. Disable it only when you have your own backup.

## Renamed sources

Once a managed source exists, the runner remembers it under `${XDG_STATE_HOME:-$HOME/.local/state}/upal/` by device, inode, and top-level names and types. If an explicit `DAT_SOURCE`, `BIN_SOURCE`, or a custom `DESKTOP_FILE_SOURCE` disappears, the next run searches for it before linking or launching:

- an exact inode match is used directly;
- otherwise at least two top-level entries, a 65% match, and a 15-point lead over the next candidate are required;
- the old parent is checked first, then the portable root three levels deep.

A match updates the source path and repairs the links. No match, or a tie, stops the run and prints the closest candidates. A broken target symlink is removed first with `rm -f`; it is never followed. The runner does not create an empty source when a source was known before, and it never replaces a valid target symlink with one. On a first run it may create `DAT_SOURCE` to adopt existing host data.

Remove `source-<key>-<role>` from the state directory to start fresh. The key is the portable root's device and inode; a same-filesystem rename keeps the history, while a cross-filesystem move rebuilds it on the next run. The state stays outside the portable folder, so the folder remains one manager file plus data.

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

An existing host path is handled in this order:

- An empty host directory is removed; nothing is lost.
- If the portable path is empty and the host path has data, the host data is copied into the portable path and becomes the portable data. The host path is then kept as `<path>.bak` before the link.
- If both sides have data, the host path is backed up as `<path>1`, `<path>2`, and so on, then replaced by the link. The portable data wins.

`BACKUP="no"` aborts instead of replacing host data.

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

### `copy`

Copies the portable path to the host path once.

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat/GIMP"
DAT_TARGET="$HOME/.config/GIMP"
DAT_METHOD="copy"
```

Existing host data is backed up as `<path>.bak` first. After the copy the two paths are independent: later changes in the folder or on the host are not reconciled. Use it when the configuration is already correct and you want a one-time snapshot, or when the app refuses links but does not need to write back.

### `copy-sync`

Copies in both directions at launch. Requires `rsync`.

At every launch:

1. If the host path is missing, copy the portable path to it.
2. Sync the host path back into the portable path with `rsync -a --update` to capture changes from the last run. Newer portable files are left alone. No files are deleted.
3. Copy the portable path to the host path with `rsync -a` so the app sees the current folder.
4. Launch the app.

This is a rough approximation, not a live sync. Conflicts are last-writer-wins, changes made while the folder is elsewhere can be missed, deletions are not propagated, and a running app can leave the host copy ahead. It is the least reliable method, a hack for apps that refuse symlinks and cannot use `env`.

### `bind`

Mounts the host path and the portable path together.

```sh
DAT_METHOD="bind"
```

Not implemented. It needs root, a mount/unmount lifecycle, and does not survive a reboot. It is the last resort for applications that replace symlinks.

### `none`

Leaves the host path alone. Use it to document a decision, or to disable a mapping inherited from a template.

## Binary modes

| Mode | Portable `bin/` | Host `BIN_TARGET` | Root |
|---|---|---|---|
| `in` | symlinks to host binaries | untouched | no |
| `out` | real binaries | symlinks to the portable folder | only for root-owned targets |
| `copy` | real binaries | untouched | no |
| host | absent | untouched | no |

Host-provided (`in`, or host mode with no `bin/`) is the default. `out` and `copy` are for offline use, a self-contained folder, or a locally compiled binary. Data portability does not depend on any of them.

`BIN_TARGET` is the host application binary directory, not a PATH directory. Multi-entry command links are separate: they go to `CMD_TARGET`, a user-writable directory on `PATH`. With multi-entry, each entry is exposed under `BIN_TARGET/<entry>/` so variant executables do not collide.

`auto` inspects the contents:

- symlinks in `bin/` → `in`;
- real executable files in `bin/` → `out`;
- empty `bin/` → `in`;
- no `bin/`, but executables at the root → `out` or `in`, by contents;
- no binaries at all → host mode.

`bin/` wins when both `bin/` and root executables exist. The runner itself is excluded from detection by its real path. Naming the runner the same as an application binary is an error.

Examples:

```sh
# Host-owned binaries, no root, updates flow through
BIN_MODE="in"
BIN_SOURCE="$PORTABLE_ROOT/bin"
```

```text
bin/gimp -> /usr/bin/gimp
```

```sh
# Folder-owned binaries, exposed in the app binary directory
BIN_MODE="out"
BIN_SOURCE="$PORTABLE_ROOT/bin"
BIN_TARGET="/opt/myapp-bin"
```

```text
bin/myapp (real)
/opt/myapp-bin/myapp -> ~/Apps/MyApp/bin/myapp
```

The target is root-owned in this example, so the runner stops and asks for a rerun with sudo. For a user-owned application directory, use a path under `$HOME`.

```sh
# Folder-owned binaries, no host changes
BIN_MODE="copy"
BIN_SOURCE="$PORTABLE_ROOT/bin"
```

## Backends

`PACKAGE_MANAGER` selects the backend. Support means the runner owns the install and run logic for that backend; there is no universal package API.

| Value | Install | Run | Root |
|---|---|---|---|
| `auto` / `native` | `pkgcli` > `pkcon` > native | command on `PATH` | yes* |
| `distro` | native package manager only | command on `PATH` | yes |
| `flatpak` | `flatpak install` | `flatpak run "$FLATPAK_ID"` | no (user) |
| `snap` | `snap install` | `snap run "$PKG"` | yes |
| `nix` | `nix profile install nixpkgs#<pkg>` | `nix run nixpkgs#<pkg>` | no |
| `brew` | `brew install` | command on `PATH` | no |
| `toolpak` | adapter-defined | adapter-defined | adapter-defined |
| `pkgit` | adapter-defined, source build | built binary | adapter-defined |
| `cpak` | `cpak install <source>` | `cpak run <pkg>` | adapter-defined |
| `none` | never | command on `PATH` | no |

\* `pkgcli` and `pkcon` may authenticate through polkit; the native package managers need root.

Toolpak and pkgit are adapter-defined: the runner needs their install and run commands and does not assume a CLI. cpak is an OCI application package format: `cpak install` takes a source such as `github.com/owner/repo`, and `cpak run` takes the package and an optional command. When the backend is not a package manager, use `app_install` and `app_run` to own the steps.

The runner never calls `sudo`. When a step needs root and the runner is not root, it stops with `This needs root: ...` and `Re-run as root: sudo ./runner`. Flatpak user installs and user-local links never need root.

Native mapping:

| Distro | Command |
|---|---|
| Debian/Ubuntu | `apt-get` (or `apt`) |
| Fedora | `dnf` |
| Arch | `pacman`, then `yay` for AUR |
| openSUSE | `zypper` |

The reference template checks whether `PKG` is on `PATH` and installs it when missing. The target contract checks `BIN_NAMES` first. If every command exists, no install happens. If one is missing, it installs the corresponding word from `PKG`. If `PKG` is empty, it searches the backend for the command name and installs an exact match. Several matches abort and print the candidates; the runner never installs an ambiguous package.

Search commands used by the native fallback: `apt-cache search`, `dnf search`, `pacman -Ss`, `zypper search`. `pkgcli` and `pkcon` search first when available.

Packages are installed one per word, so `PKG="adb fastboot heimdall scrcpy"` loops over four packages. `BIN_NAMES` is separate because a package name and a command name often differ.

## Flatpak profile

Only `FLATPAK_ID` is required. `FLATPAK_SCOPE` defaults to `user`; set it to `system` for a system-wide install. The engine fills the standardized paths, and a data or binary source selects the portable sides. Set `PACKAGE_MANAGER` only if you want to override the backend.

| Path | User install | System install |
|---|---|---|
| deployment | `~/.local/share/flatpak/app/$FLATPAK_ID` | `/var/lib/flatpak/app/$FLATPAK_ID` |
| data | `~/.var/app/$FLATPAK_ID` | `~/.var/app/$FLATPAK_ID` |
| desktop export | `~/.local/share/flatpak/exports/share/applications/$FLATPAK_ID.desktop` | `/var/lib/flatpak/exports/share/applications/$FLATPAK_ID.desktop` |

Derived values:

- `PACKAGE_MANAGER="flatpak"` when it was `auto`.
- `FLATPAK_SCOPE` is `user` by default; `system` uses the system installation.
- `DAT_TARGET="$HOME/.var/app/$FLATPAK_ID"` when `DAT_SOURCE` exists and `DAT_TARGET` is empty.
- `DAT_SOURCE` is inferred from `LANG_INFERRING_DATA` when empty; no data directory means no data mapping.
- `BIN_SOURCE` is inferred from `LANG_INFERRING_BIN` when empty; no binary directory means no binary reference.
- If the binary directory is a symlink, it is used as-is. Point it at the active deployment's `files/bin` (or `files`) to expose the binaries without generated files.
- If the binary directory is real, `BIN_TARGET` becomes the active deployment's `files/bin` (or `files`), and `$BIN_SOURCE/$FLATPAK_ID` becomes a read-only reference symlink to it. The link uses `active`, so it follows Flatpak updates.
- No launcher is generated; `run` calls `flatpak run --user|--system "$FLATPAK_ID" "$@"`.
- If no portable icon is present, the exported Flatpak icon is used for the `gio` folder metadata on the portable root, the data target, and `BIN_TARGET` when set. The icon name comes from the exported desktop file's `Icon=` value, falling back to `$FLATPAK_ID`.
- The Flatpak installation is not modified. `flatpak run` resolves the architecture, branch, and active deployment.
- Desktop entry and icon come from the Flatpak export when present.
- `PKG` is not used; a missing app is installed with `flatpak install --user|--system -y flathub "$FLATPAK_ID"`.

If `flatpak` is missing, the runner tries `pkgcli`, then `pkcon`, then the distro package manager. It adds the flathub remote when needed and asks for a reboot after installing Flatpak itself. The reboot message exits the run; launch it again after rebooting.

```sh
FLATPAK_ID="com.developer.App"
FLATPAK_SCOPE="user"
```

```text
MyApp/
├── runner
├── dat/   # optional
└── bin/   # optional
```

Create only `dat/` to preserve data, only `bin/` to keep a binary reference, or both. The runner does not create the side you omit. An explicit side that disappears triggers rename recovery; if you intend to stop preserving it, remove the matching `source-<key>-dat` or `source-<key>-bin` state file. A Flatpak `bin/` is the exception: it is a host reference, so deleting it is not treated as a rename and the app still launches.

The data path is the same for user and system installs. User scope never needs root; system scope may need administrator authentication. The binary source is optional and has two forms: a symlink to the active deployment's `files/bin` (or `files`), or a real directory holding `$BIN_SOURCE/$FLATPAK_ID` as a read-only reference to the same deployment. Both leave the Flatpak installation untouched. No launcher is generated; `run` calls `flatpak run`. Flatpak does not support symlinking an individual app installation directory (`~/.local/share/flatpak/app/$FLATPAK_ID` or `/var/lib/flatpak/app/$FLATPAK_ID`); the runner never does that. Symlinking the arch directory (`.../app/$FLATPAK_ID/$ARCH`) is not a workaround: Flatpak stops listing the app, and update/uninstall cannot find it. Symlinking the deployment's `files` directory itself is also not enough: listing and updates still work, but `flatpak run` fails in bwrap. Symlinking an entry **inside** `files` works when the target is exposed to the sandbox with a read-only filesystem override; `FLATPAK_OFFLOAD` does that. It keeps `files` a real directory, so listing and updates still work, and the override lets `flatpak run` resolve the symlink.

```sh
FLATPAK_OFFLOAD="app-bundle"
```

`FLATPAK_OFFLOAD` takes space-separated top-level names under the active deployment's `files/`. For each name, the runner moves it to `$BIN_SOURCE/<name>`, replaces the deployment entry with a symlink, and adds `flatpak override --user --filesystem="$BIN_SOURCE:ro"`. On an update, the new deployment entry is moved in and the previous target is kept as `<name>1`, `<name>2`. Do not list `.ref`; it is used for deployment locking. The app installation must be writable: user scope needs no root, system scope does. This is experimental; a future Flatpak release can change the behavior.

The supported whole-installation route is `FLATPAK_USER_DIR` or a custom installation; a bind mount offloads one app without the override. The data path `~/.var/app/$FLATPAK_ID` is separate, and Flatpak resolves a symlinked data directory (tested with Flatpak 1.16). Some applications write outside `~/.var/app/$FLATPAK_ID`; add those paths explicitly with the `redirect` helper in a hook. Heroic's `~/Games` is the common example.

## Detection

Empty `DAT_SOURCE` or `BIN_SOURCE` means name inference. An explicit value disables it for that side.

- The lists `LANG_INFERRING_DATA` and `LANG_INFERRING_BIN` supply the names. Each word is checked at `$PORTABLE_ROOT/<word>` and `$PORTABLE_ROOT/*/<word>`.
- One match sets the source. Several matches abort and print the candidates. No match leaves that side off.
- `ENTRIES` disables binary inference; the entries name their own directories.
- A source cannot live inside the other role: data inside the binary directory, or the reverse, aborts.
- If `DAT_TARGET` is set, no data directory matched, and the data list is not empty, `$PORTABLE_ROOT/<first data word>` is created, so existing host data can be adopted.
- Inference never deletes a real file or directory, and it never inspects file contents. The lists are the only source of names.

A detected source is used as-is. Rename recovery applies to explicit paths; a detected directory that is later renamed is found again only if its new name is in the list.

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
    cp "$ICON_SOURCE/sndcpy.svg" "$ICON_TARGET/sndcpy.svg"
    sed -i "s|^Icon=.*|Icon=sndcpy|" \
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

## Multi-entry suites

If `BIN_SOURCE` contains only subdirectories, the runner treats each subdirectory as a variant. With `PKG="myapp"` and `bin/stable`, it looks for:

- `bin/stable/myapp-launcher` or `bin/stable/myapp`;
- `myapp_stable.desktop` at the portable root, or `bin/stable/myapp.desktop`;
- `myapp.svg` at the portable root, or `bin/stable/myapp.svg`.

The header stays the normal one; no list is needed. Auto-detected entries share one icon (`Icon=myapp`). If `BIN_TARGET` is set, each entry's executable is linked into `BIN_TARGET/<entry>/`; the command link in `CMD_TARGET` points there. This keeps variants from colliding in one binary directory. If `BIN_TARGET` is empty, the command link points directly at the portable executable. `DEFAULT_ENTRY` selects the default; otherwise the first entry. Set `LAUNCHER` to an external chooser to pick at launch; `run <entry>` bypasses it.

For a layout that does not follow the convention, set `ENTRIES` explicitly, one line per entry:

```text
name|bindir|executable|desktop|icon|icon_id
```

- `name` — argument used by the desktop entry and by the runner.
- `bindir` — directory relative to the portable root; the runner changes into it before launching.
- `executable` — executable relative to `bindir`.
- `desktop` — desktop file relative to the portable root.
- `icon` — icon relative to the portable root; empty falls back to `ICON`.
- `icon_id` — theme name and `Icon=` value; empty uses the package icon. Auto-detected entries share it; set explicit IDs only when the entries need different icons.

For each entry the runner installs the icon, links the desktop file, removes `TryExec=`, sets `Icon=<icon_id>`, creates `<pkg>-<name>` in `CMD_TARGET` pointing at the entry executable or its `BIN_TARGET/<name>/` copy, and rewrites `Exec=` to that command plus the original field codes. If `CMD_TARGET` is not on `PATH`, the absolute link path is used. `run <name> [args]` launches that entry; with no name, `DEFAULT_ENTRY` is used, then the first entry. If an entry has no executable and `app_run` is defined, the hook is called instead.

Example:

```sh
ENTRIES="
stable|bin/stable|myapp-launcher|myapp_stable.desktop|bin/stable/myapp.svg|myapp-stable
beta|bin/beta|myapp-launcher|myapp_beta.desktop|bin/beta/myapp.svg|myapp-beta
"
```

Keep each line at column 0; fields are split on `|`, so a path containing `|` is not supported. Each entry gets its own command link, so `myapp-stable` starts the stable build from any directory. `ENTRIES` replaces the single-app desktop/icon path; `DESKTOP_FILE_NAME` and `ICON_NAME` still provide the folder icon and fallback.

## Desktop entries

The runner links every `*.desktop` file from `DESKTOP_FILE_SOURCE` into `~/.local/share/applications` and rewrites `Exec=` to the runner when `DESKTOP_REWRITE_EXEC="yes"` (the default). Standard field codes (`%U`, `%F`, `%u`, `%f`) are kept; other host-specific arguments are dropped. Set `DESKTOP_REWRITE_EXEC="no"` when the folder holds a suite and each entry launches a different tool, as in the adb example. `DESKTOP_FILE_NAME` limits which entry gets the icon rewrite, not which entries are linked.

## Icons

Exactly one image at the portable root, or in `ICON_SOURCE`, becomes the icon. Detection uses the MIME type, not the filename or extension, so a PNG named `icon.svg` or an SVG named `banana` works. Auto-detected icons use the package name as the theme ID, so renaming the file changes nothing for the desktop entry. If more than one image is present, the runner does not guess: it restores the default icon. `ICON_NAME` pins an exact file.

The runner installs the icon into the hicolor theme at `~/.local/share/icons/hicolor/scalable/apps/<id>.svg` (or `256x256/apps/<id>.png`) and sets `Icon=<id>` in the desktop entry. Moving the folder does not break the entry.

When the icon changes, the previous theme icon is kept as `<id>.<ext>1`, then `<id>.<ext>2`, and so on. A format change archives the previous format in its own theme directory, so the default still survives. Deleting the image at the portable root restores the oldest archive as the active icon and removes the newer ones, so the default comes back without manual path management. The oldest archive stays in place for later runs. The last icon's id, extension, and theme directory are remembered under `${XDG_STATE_HOME:-$HOME/.local/state}/upal/`, so an auto-detected icon can be restored after its source file is deleted.

- `ICON_ID` is the theme name. Empty uses the package name for an auto-detected icon, or the source filename without its extension when `ICON_NAME` is pinned; set a reverse-DNS name such as `com.app.developer` to avoid collisions.
- `ICON_TARGET` overrides the theme directory.
- `ICON_METHOD` is `copy` (default), `link`, or `none`. `copy` survives moving the folder. `link` updates with the source but breaks when the folder moves; the next run repairs it. `none` leaves the desktop entry on the absolute portable path.
- `gio` sets `metadata::custom-icon` on the portable root and on `DAT_TARGET` from the portable file.
- Deleting the image restores the archived icon, or removes the managed theme icon when there is no archive. It also unsets the folder metadata with `gio set -t unset`. The next run installs the icon again if a new image appears.

## Environment

| Variable | Effect |
|---|---|
| `UPAL_DRY_RUN=1` | Print planned actions, change nothing, exit 0. |
| `UPAL_VERBOSE=1` | Print recovered source paths and actions. |

Environment variables are used instead of CLI flags so application arguments from `%U` and `%F` pass through untouched.

## Root and sudo

The runner never invokes `sudo`, `doas`, or another escalator. It runs as the user and stops when a step needs root:

```text
This needs root: link man pages into /usr/share/man/man1
Re-run as root: sudo ./runner
```

- User-local paths (`~/.local`, `~/.config`), Flatpak user installs, Nix, and Homebrew need no root.
- System package managers (`apt`, `dnf`, `pacman`, `zypper`, `snap`) and system directories (`/usr/share/man`, `/usr/local/bin`) need root.
- When run through `sudo` or `doas`, the engine uses `SUDO_USER`/`DOAS_USER` to keep `HOME` pointed at the invoking user, and gives created files back to that user.
- Run the whole runner as root only when it asks. A Flatpak runner should never ask.

## Safety rules

1. Never replace a real file or directory without a successful backup. If the target is root-owned, run the runner with sudo; the engine never invokes sudo. Abort if the backup fails.
2. Only touch links whose name is managed and whose target belongs to this runner. No broad globs.
3. Empty target directories are removed. Host data adopted into the portable folder keeps a `.bak` copy; a real conflict is backed up as `<path>1`, `<path>2`, and so on. Never overwrite. `BACKUP="yes"` is the default.
4. Every run is idempotent.
5. Switching modes never deletes real binaries. `out` → `in` aborts if real files occupy the link paths.
6. The filesystem check runs once on `$PORTABLE_ROOT` and exits cleanly. NTFS, exFAT, and similar filesystems are refused.
7. Quote every path. Use `--` for commands that accept it.
8. Do not run the same portable folder twice at the same time, and do not move it while the application is running.
