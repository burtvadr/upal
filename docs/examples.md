# Examples

Each example is a complete portable root. Only the header and the app-specific hook block change; the engine is the same file.

> These examples use the target header. The reference template implements the `link`, binary `out`, and icon subset; see the status table in the README.

The examples are data-first. Binaries are optional; the host package manager can provide them.

## Data only: the main use case

The application is installed by the host; only its data is portable.

```text
MyApp/
├── runner
└── dat/
```

```sh
PKG="myapp"
BIN_NAMES="myapp"
DAT_SOURCE="$PORTABLE_ROOT/dat"
DAT_TARGET="$HOME/.config/myapp"
DAT_METHOD="link"
BIN_MODE="auto"
```

There is no `bin/`, so the runner uses the host command. The first run moves existing host data into `dat/` and links it back. Reinstalling or upgrading the application does not touch the data.

## Minimal: click and run

No binaries and no data in the folder. The runner installs the package if needed and runs it.

```text
MyApp/
└── runner
```

```sh
PKG="myapp"
BIN_NAMES="myapp"
DAT_TARGET=""
BIN_MODE="auto"
```

This is the "click and run" case. Nothing is portable except the launcher.

## GIMP: portable data, host binary

The host package provides GIMP; the folder owns the configuration.

```text
GIMP/
├── runner
├── gimp.desktop
├── gimp.svg
└── dat/
```

```sh
PKG="gimp"
BIN_NAMES="gimp"
DAT_SOURCE="$PORTABLE_ROOT/dat"
DAT_TARGET="$HOME/.config/GIMP"
DAT_METHOD="link"
BIN_MODE="auto"
DESKTOP_FILE_NAME="gimp.desktop"
ICON_NAME="gimp.svg"
NAME="GIMP"
```

First run:

- installs `gimp` if missing;
- moves existing `~/.config/GIMP` into `dat/`, then links it back;
- links `gimp.desktop` into `~/.local/share/applications`;
- rewrites `Exec=` to the runner and `Icon=` to the portable icon;
- runs `gimp`.

Because there is no `bin/`, `BIN_MODE="auto"` selects host mode: no sudo and no binary links.

## Firefox: XDG environment override

Firefox is launched with a private `XDG_CONFIG_HOME`, without touching the global environment.

```text
Firefox/
├── runner
└── dat/
    └── config/
```

```sh
PKG="firefox"
BIN_NAMES="firefox"
DAT_SOURCE="$PORTABLE_ROOT/dat/config"
DAT_METHOD="env"
DAT_ENV="XDG_CONFIG_HOME"
BIN_MODE="auto"
NAME="Firefox"
```

The runner exports:

```text
XDG_CONFIG_HOME=~/Apps/Firefox/dat/config
```

Firefox appends its own directory, so the profile ends up in `dat/config/firefox/…`.

Caveat: `XDG_CONFIG_HOME` is a base directory. Do not point it at `dat/config/firefox`; that produces `dat/config/firefox/firefox/…`. Firefox also has its own profile management, so test this with a throwaway profile before trusting it.

For a specific path, use `link` instead:

```sh
DAT_SOURCE="$PORTABLE_ROOT/dat/firefox"
DAT_TARGET="$HOME/.mozilla/firefox"
DAT_METHOD="link"
```

## Flatpak: only the app ID

Flatpak paths are standardized, so the profile fills them.

```text
Heroic/
├── runner
└── dat/
```

```sh
PACKAGE_MANAGER="flatpak"
FLATPAK_ID="com.heroicgameslauncher.hgl"
DAT_SOURCE="$PORTABLE_ROOT/dat"
DAT_TARGET="$HOME/.var/app/$FLATPAK_ID"
DAT_METHOD="link"
BIN_MODE="auto"
NAME="Heroic"
```

`DAT_SOURCE` and `DAT_TARGET` can be omitted; the profile derives them from `FLATPAK_ID`. The runner installs with `flatpak install`, runs with `flatpak run`, and does not link the Flatpak binary. The data path is `~/.var/app/$FLATPAK_ID` for both user and system installs.

Heroic also writes games to `~/Games`. Add it explicitly:

```sh
app_pre_link() {
    redirect "$PORTABLE_ROOT/games" "$HOME/Games" link
}
```

## adb: portable binaries and data

The folder carries the Android tools from Google; the host gets links. The only valuable data is `~/.android`.

```text
adb/
├── runner
├── bin/
│   ├── adb
│   ├── adb.1
│   ├── disconnected.png
│   ├── etc1tool
│   ├── fastboot
│   ├── heimdall
│   ├── hprof-conv
│   ├── icon.png
│   ├── lib64
│   ├── make_f2fs
│   ├── make_f2fs_casefold
│   ├── mke2fs
│   ├── mke2fs.conf
│   ├── NOTICE.txt
│   ├── scrcpy
│   ├── scrcpy.1
│   ├── scrcpy.png
│   ├── scrcpy-server
│   ├── sndcpy
│   ├── source.properties
│   └── sqlite3
├── camcpy.svg
├── dat/
│   ├── adb.5037
│   ├── adbkey
│   ├── adbkey.pub
│   ├── adb_known_hosts.pb
│   ├── analytics.settings
│   ├── cache
│   ├── debug.keystore
│   └── debug.keystore.lock
├── scrcpy.desktop
├── scrcpy.svg
├── sndcpy.desktop
└── sndcpy.svg
```

```sh
PKG="adb fastboot heimdall scrcpy"
BIN_NAMES="adb fastboot heimdall scrcpy"
BIN_MODE="out"
BIN_SOURCE="$PORTABLE_ROOT/bin"
BIN_TARGET=""
DAT_SOURCE="$PORTABLE_ROOT/dat"
DAT_TARGET="$HOME/.android"
DAT_METHOD="link"
DESKTOP_FILE_NAME=""
ICON_NAME="scrcpy.svg"
NAME="adb, fastboot, heimdall and scrcpy"

app_pre_link() {
    adb kill-server
}

app_post_link() {
    sed -i "s|^Icon=.*|Icon=$ICON_SOURCE/sndcpy.svg|" \
        "$DESKTOP_FILE_SOURCE/sndcpy.desktop"
}
```

`BIN_TARGET=""` means the first writable `PATH` directory, usually `~/.local/bin`. The runner links each executable there and backs up anything it replaces. Support files (`lib64`, `scrcpy-server`, the notices) stay in `bin/` next to the executables; only executable files are linked.

The `app_pre_link` hook stops a running adb server before the data link changes. The `app_post_link` hook gives `sndcpy.desktop` its own icon.

If you prefer distro packages, drop `bin/`, set `BIN_MODE="auto"`, and keep the same `dat/` mapping. The data does not change with the binary source.

## Immich: a container stack as one app

Immich is a web stack, not a desktop binary. The compose project directory is the portable data, so relative paths do the work.

```text
Immich/
├── runner              # open-immich, the only manager file
├── docker-compose.yml
├── docker-compose.yml.bak
├── library/
├── postgres/
├── run/
├── up-immich
├── down-immich
├── stop-immich
├── immich.desktop
└── immich.svg
```

```sh
PKG=""
PACKAGE_MANAGER="none"
BIN_NAMES=""
DAT_SOURCE="$PORTABLE_ROOT"
DAT_TARGET=""
DAT_METHOD="none"
DESKTOP_FILE_NAME="immich.desktop"
ICON_NAME="immich.svg"
NAME="Immich"

app_run() {
    cd "$PORTABLE_ROOT" || exit 1
    docker compose up -d
    xdg-open "http://localhost:2283"
}
```

There is no host data link: `docker-compose.yml` uses relative paths (`./library`, `./postgres`, `./run`), so moving the folder moves the stack. `up-immich`, `down-immich`, and `stop-immich` are lifecycle helpers; `app_run` is what the desktop entry calls. `docker-compose.yml.bak` is an ordinary file backup, unrelated to the `.bak` data safety.

`PACKAGE_MANAGER="none"` keeps the runner out of the package manager. Docker is the runtime; the runner only owns the entry point and the folder layout.

## Self-contained: binaries in the folder, no host links

Optional. Use this for offline machines or a binary you compiled yourself.

```text
MyApp/
├── runner
├── bin/
│   └── myapp
└── dat/
```

```sh
PKG=""
BIN_NAMES="myapp"
BIN_MODE="copy"
BIN_SOURCE="$PORTABLE_ROOT/bin"
DAT_SOURCE="$PORTABLE_ROOT/dat"
DAT_TARGET="$HOME/.local/share/myapp"
DAT_METHOD="link"
NAME="MyApp"
```

`copy` mode runs the binary from the folder and leaves the host `PATH` alone. Data still links back to the folder. This is the closest to a classic Windows portable folder.

## Host-owned binaries: no sudo, updates flow through

```sh
PKG="gimp"
BIN_NAMES="gimp"
BIN_MODE="in"
BIN_SOURCE="$PORTABLE_ROOT/bin"
DAT_SOURCE="$PORTABLE_ROOT/dat"
DAT_TARGET="$HOME/.config/GIMP"
DAT_METHOD="link"
```

```text
bin/gimp -> /usr/bin/gimp
```

The folder contains a link to the host binary. The host package manager updates it normally. The folder remains small and legal to redistribute without the application.

## Nautilus bundle (planned)

Once the Nautilus patch lands, the folder itself can be the thing you double-click.

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

The manifest is optional desktop integration, not a second manager. Normal directories keep opening normally. The first launch asks for confirmation, and downloaded bundles always require it.

## Layout rules

- The runner must stay at the portable root, or be symlinked to it; it resolves its own real path.
- `bin/` and `dat/` are defaults, not requirements. Point `BIN_SOURCE` and `DAT_SOURCE` anywhere.
- If `bin/` and root executables both exist, `bin/` wins.
- The runner never treats itself as an application binary.
- Do not name the runner the same as an application binary.
