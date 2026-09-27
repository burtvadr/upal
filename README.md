# upal
Universal Portable Abstraction Layer

a lightweight middleware engine that decouples application data from the host operating system's rigid file structure. Instead of competing with the host's package manager, it orchestrates it, simulating a self-contained "Windows-style" portable folder while secretly leveraging the host's native tools behind the scenes.

Here is the architectural breakdown of how this abstraction operates:

### 1. The Core Architecture

* **$PORTABLE_ROOT:** To the user, the application is simply a folder containing a executable and your user data. This folder can be moved across drives, partitions, or entirely different operating systems.
* **The Executable:** a single executable acts as a context-aware engine. When clicked, it detects its environment and dynamically routes the application's data from the portable folder to the host operating system before launching the program.
* **Package Manager Agnosticism:** The abstraction layer buy default doesn't care how the binary is obtained. It can trigger a Flatpak installation, use the distro's native package manager (like APT, DNF, or pacman), fetch a GitHub release, compile from source with pkgit or simply extract a tarball. The installation backend is completely abstracted away from the user experience.

### 2. Dependency & Data Handling

* **Host-Provided Binaries:** Unlike containerized formats like AppImage that bundle every single library, this approach can rely on the host system to provide the heavy lifting. By default the OS manages the binaries, while the portable directory manages the identity and state of the app.
* **Isolated User Data:** portability also lies in the user data. The engine intercepts where the application naturally wants to save its data (e.g., `~/.config`, `~/.local/share`, or `~/.var/app/`) and forces it into the portable directory. This is typically achieved via dynamic symlinking, environment variable overrides or OS specific features

### 3. (Optional) Desktop Integration

* **On-the-Fly Customization:** The moment the runner is executed, it automatically bridges the gap with the host OS. if needed it generates and registers `.desktop` files in the host's application menus, applies custom icons, and maps executables to standard PATH directories.
* **Zero-Friction State Management:** Because all configurations, layouts, plugins, and save states live inside the portable root, the host OS is treated as a disposable compute node. If you move the portable folder to a new machine, your exact workspace is instantly restored.

This approach essentially takes the absolute best part of Windows portable apps—the unified data directory—and marries it to the security and dependency management of modern Linux package ecosystems.

---

# Practical Pattern for Portable Packages

This document describes a practical approach to achieving **portability** for any application regardless of package format by encapsulating the application, execution logic, and persistent user data inside a single, movable directory.

> **Goal:** transferring an application and its configuration between PCs should be as simple as copying a folder from a desktop to a laptop and running the program instantly.

---

## 1. Summary

The current concept of "portable software" is fragmented. Formats like AppImage offer single-file portability, but they do **not** encapsulate *user data* (configurations, saves, caches) inside the same container, which leads to data fragmentation.

This approach provides a pragmatic mechanism to encapsulate both application execution logic and persistent user data and optionally binaries into a single movable directory. The folder is driven by an embedded logic that acts as middleware between the user and the package manager. The launcher detects location and names and launches the application.

---

## 2. Problem: Package Manager Limitations

Most package managers install to rigid, hard-coded paths:

1. **Binary location:** `/usr/bin`, `/var/lib/flatpak`, `~/.local/share/flatpak`, etc.
2. **Data location:** `~/.var/app/`, `~/.config/`, `~/.local/share/`, etc.

**Consequences:**

* Users cannot easily move an installation to a secondary drive to free root partition space.
* Formatting the root partition results in data loss. Backing up entire config directories can be redundant.
* Manually selecting which data subfolders to back up is annoying.
* Syncing application state between machines requires managing multiple directories.

These constraints motivated the practical approach described below.

---

## 3. The Ideal Portable Application

Use a flexible logic that acts as middleware between the user and the package manager. Your one-click `runner` is an engine: it detects its own location, handles names, new locations, detects edge cases, preserve existing data and launches the application. You can name the `runner` whatever you want.

### 3.1 Core Philosophy

* **Adaptable:** Users should be able to rename and move directories freely. The system should predict and detect the folder's current absolute path and still work when the folder moves directories or names.
* **Renameable:** Directories like `$PORTABLE_ROOT` can be renamed, the runner resolves its own location dynamically, so names are irrelevant.
* **Movable:** The portable directory can be relocated across drives, mount points, or filesystems. The runner recalculates all paths on each launch.
* **No metadata files:** Configuration is kept internally to avoid extra files and clutter.
* **Expressive layout:** Users should be free to organize the portable directory to their taste; a sensible default structure should exist.

This is a tooling-first approach intended to work now rather than a formal standard.

### 3.2 Possible Directory Structures

You should be able to have a flexible structure that preserves your needs, with the freedom to name everything whatever you want:
These directories can have their names changed at any time by the user, so the logic will never use names as the sole identifying factor.
**Hard Constraints:**
* The user should never rename or move the folder while the app is running.
```
$PORTABLE_ROOT/                     # package root, # renameable # movable
├── runner                          # one-click executable, run the application (Entry Point) # renameable
├── stuff                           # (Optional) anything the user would want to keep; should never break anything # renameable
├── binaries                        # (Optional) offloaded package binaries # renameable
└── data                            # (Optional, On by default) Persistent User Data # renameable
```

Or, in a minimal layout:

```
$PORTABLE_ROOT/
├── runner
├── stuff
└── data
```

If you want to go even more minimal:

```
$PORTABLE_ROOT/
├── Brave                           # one-click executable
├── Discord                         # one-click executable
├── Steam                           # one-click executable
```

The setup above effectively works as a script that installs the package from any source (native package manager, Flatpak, AppImage, GitHub release, tarball, etc.) and executes it, with one click.

### 3.3 Dynamic Detection Mechanism

**User A — Data Persistence**
* **Trigger:** Presence of `"$DATA"` and absence of `"$BIN"`
* **Results:** Keep only user saves/configuration portable; binaries remain on the host. Binaries are retrievable from the package source.

**User A.2 — Binary Offloading**
* **Trigger:** Presence of `"$DATA"` and presence of `"$BIN"`
* **Results:** Store both binaries and user data on the portable directory.

**User C — Click and Run**
* **Trigger:** Absence of `"$DATA"` and absence of `"$BIN"`
* **Results:** Effectively just installs the application and executes it.

### 3.4 Declaring `"$DATA"` and `"$BIN"` Through Contents
lets say the user just dont like the name of the directory, and it want to use its native language

```
├────────── $PORTABLE_ROOT
├── данные       # `"$DATA"`
│   ├──  cache
│   ├──  config
│   ├──  data
└── runner
```

The system should automatically identify where is the `"$DATA"` by:

### 3.5 Contents-Aware System — No Configuration

The system should detect with no extra configuration needed what the user wants to keep portable, through the presence or absence of directories or files, andd its contents. So users don't need by default edit config files or use the terminal.

```
├────────── $PORTABLE_ROOT
│   └── cat photos
├── program
│   ├── scripts
│   └── данные
│       ├── cache
│       ├── config
│       ├── data
└── runner                 # one-click run application (Entry Point) # renameable
```

By automatically or manually setting up a list of what is the contents of program X user data directory,
Even in this setup, the system should be able to detect `$DATA="данные"`.

But if directories are empty and `"$DATA"` and `"$BIN"` couldn't be determined by their contents, we proceed with:

### 3.6 (Optional) Assumptions

* Helps you install the application, and the system knows what the `"$DATA"` and `"$BIN"` directory locations are.
* assumptions are on by default. Directories named (`dat`), (`data`), or (`dados`) are detected as `"$DATA"`.
* (`bin`), (`binaries`), (`binarios`) as `"$BIN"`.
* You should be free to control assumptions by creating your own list or disabling them completely.
* If more than one of those types exist, choose in alphabetic order the first directory that is empty.
* (e.g., `$PORTABLE_ROOT/bin/dat`) is naturally invalid. (e.g., `$PORTABLE_ROOT/$DATA/"$BIN"`) also is invalid — abort.
* (e.g., `$PORTABLE_ROOT/binaries/bin`) should validate the last and not fire too early. Be aware of (e.g., `$PORTABLE_ROOT/$BIN/"$BIN"`) — validate the last one.
* assumptions should only be used if declaring `"$DATA"` and `"$BIN"` through contents failed.

### 3.7 Limitations

**Default Constraints:**
* `"$DATA"` and `"$BIN"` folders cannot be searched more than two directories deep.
* Naturally avoid NTFS or other unsupported filesystems:
```
notify-send "Error" "File system unsupported, Move into a linux File system drive\!" -u critical
```
(Optional, but for linux no NTFS by default. some apps dont mind NTFS,)

Some package formats have deep, predictable binary layouts (e.g., Flatpak runtimes with `current -> x86_64/stable` symlinks). Detecting these surgically adds exponential complexity, so the system focuses on content-based and name-based detection.


---

## 4. (Optional) Desktop Integration

* also uses assumptions.
* Naturally, opening packages adds a desktop entry to your desktop environment. We want to preserve this behavior by default.
* You should be able to disable desktop integration, so you can only run the application by clicking the `runner`.
* Automatically applies a custom icon by detecting the presence of any image inside `$PORTABLE_ROOT` — you don't have to edit anything manually.

```
├────────── $PORTABLE_ROOT
├── runner
├── icon        # uses --mime-type to detect media: .png, .svg, .ico, .jpg, .jpeg, .webp never depend exclusively on file extension
├── binaries
└── data
```

By dragging any image onto `$PORTABLE_ROOT`, we should automatically apply it by editing the `icon=` line on the desktop file — whether it's a system-wide install at `/usr/share/applications/$PACKAGE_ID.desktop` or a user install at `~/.local/share/applications/$PACKAGE_ID.desktop`.

* Users may also want to keep a custom `.desktop` file. Like everything here, we should automatically apply it by its presence.
* If you don't want a desktop file, just don't have any in `$PORTABLE_ROOT`.

```
├────────── $PORTABLE_ROOT
├── runner
├── stuff
├── icon.png       # any image format
├── custom.desktop
├── binaries/
└── data/
```

If a desktop file is already included in `$PORTABLE_ROOT`, just edit the `icon=` line on this desktop file. No need to touch the system or user application directories.

## 5.1 Portable Folder Icon Integration

The portable directory should visually represent the application by automatically applying an icon to the **folder itself** `"$PORTABLE_ROOT"`.

### Behavior

At launch time, the runner selects a single image to represent the portable folder:

* **Primary source:** any image located at the root of `$PORTABLE_ROOT`
* **Fallback source:** the application icon exported by the package at the standard export path for the package format.

The selected image is resolved to an absolute path. The icon must remain valid after the portable directory is relocated to a different mount point or system.

### Nautilus Integration Model

GNOME Files (Nautilus) supports per-directory custom icons through filesystem metadata. The runner applies the resolved image path as the directory's custom icon so the folder consistently appears with the application icon in Nautilus views (grid, list, sidebar, recent locations).

The icon assignment is metadata-based and does not modify the directory contents. Clearing this metadata restores the default folder appearance.

### Portability Constraints
* Absolute paths must be recalculated when the portable directory is moved.
* Icon metadata may be cached by Nautilus; visual updates are not guaranteed to be immediate.

---

## 6. Automating Permissions (Optional, On by Default)

At launch time the runner evaluates the override file state:

* **If the override file for `$PACKAGE_ID` does not exist or is empty:**
  * The runner writes the portable override into this location (if one is defined internally).
  * This enables the required permissions for the portable app.

* **If the override file exists and is not empty:**
  * The runner reads it into memory.
  * If the contents differ from the internally defined override, the runner prefers the existing user override and applies in-memory normalization only.
  * No file is duplicated or stored elsewhere.

* **Override files should be stored internally inside the own `runner`.** No annoying extra files or hidden files.

### Path and Username Normalization

For migrating between distros that use `/run/media` or on a system with a new username:

* Convert usernames and media mount inside paths:

```
/media/burtjo/... → /run/media/jason/...
```

**Example:**

```
[Context]
devices=dri
filesystems=/media/burtjo/SSD/SteamLIB;/media/burtjo/SSDpkg/Gaming/Steam
```

becomes

```
[Context]
devices=dri
filesystems=/run/media/jason/SSD/SteamLIB;/run/media/jason/SSDpkg/Gaming/Steam
```

The resulting content is written directly to the appropriate override location.

---

## 7. Symlink Trick

Package managers look for user data in different locations depending on the format:

* Flatpak: `~/.var/app/$PACKAGE_ID`
* Native packages: `~/.config/$PACKAGE_ID`, `~/.local/share/$PACKAGE_ID`
* Custom: any path the application uses

Using symlinks to achieve portable applications — by redirecting those locations to the portable folder — without patching the package manager.

This symlink method works for any package format, though complexity can increase with deeply nested or runtime-managed layouts.

---

## 8. Practical Execution Logic

0. **On your one-click `run`, the system should:**

1. **Automatically install the package from the appropriate source** — whether that's the distro's package manager (`apt`, `dnf`, `pacman`), Flatpak + Flathub, a GitHub release tarball, or a direct download. The backend is abstracted.

2. **Compute its current absolute path** for `$PORTABLE_ROOT`. Example: `/media/user/USB/Games/Osu`

3. **Define the `"$DATA"` and `"$BIN"` directories** using the contents-aware method, or the language assumption if contents-aware fails.

4. **Define a valid `$PACKAGE_ID`:**
   * We need a constant and unique identifier for the application.
   * Check if `$BIN/current/active/export/bin/$PACKAGE_ID` exists (for Flatpak).
   * Check if the runner filename is a valid `$PACKAGE_ID`.
   * Store internally — no extra files.

5. **Definitions:**
   * After `$PACKAGE_ID` is detected, define its own absolute path as `$PORTABLE_ROOT`.
   * Define `[USER_MODE]` for user install (default) or `[SYSTEM_MODE]` for system-wide install.
   * Define `$BIN_TARGET` based on the package format's binary location.
   * Define `$DESKTOP_FILE` — either from `$PORTABLE_ROOT` or from the package's export path.

6. **If it's already installed:**
   * Compare how it's installed with how the `[Portable Path]` configuration is determined.
   * If the data target is a broken symlink (from a previous location), remove it.
   * If the data target is not a symlink and the user language assumption applies:
     * Check if the detected `"$DATA"` directory is empty.
     * If empty, move the data from the host location to the `"$DATA"` directory.
   * If the host data is a standard directory, rename it by appending a rotation suffix (e.g., `com.vendor.org` → `com.vendor.org1`) so the original is backed up. If `com.vendor.org1` already exists, rotate to `com.vendor.org2`, and so on.
   * If `$BIN_TARGET` is a broken symlink, remove it.
   * If `$BIN_TARGET` is a functional symlink, delete it to prepare for a new link.

7. **If it's already installed at an opposing mode (system-wide vs user):**
   * Uninstall and reinstall to the right mode by default.
   * Or migrate: wipe internal `"$BIN"` and move the host binaries to `"$BIN/"`, then symlink.
   * If not using a `[LOCAL_DESKTOP_FILE]` and `DESKTOP_INTEGRATION=1`:
     * Move the desktop file to the user location.
     * Symlink appropriately.

8. **Linking:**
   * Dynamically symlink what is needed based on the configuration of the directories layout.
   * Symlink `"$DATA"` to the host data location.
   * Symlink `"$BIN"` to `$BIN_TARGET`.
   * Symlink `[LOCAL_DESKTOP_FILE]` to `[DESKTOP_FILE]`.

9. **If it's not already installed:**
   * Install according to configuration.

10. **Icon phase:**
    * If `[ICON]` exists, change the `[DESKTOP_FILE]` or `[LOCAL_DESKTOP_FILE]` (if it exists) `icon=` line to include the `[ICON]` absolute path.

11. **Execution phase:**
    * Just before execution, you can have a shell script for handling anything you want with the set variables.
    * The runner executes the application.
    * Option: provide a toggle to run with a terminal (off by default).

---

## 9. Practical Considerations & Edge Cases

* **Permissions:** Offloading system-installed packages often requires elevated privileges to manipulate system directories. User-level installs are easier to manage without `sudo`.
* **Broken Symlinks:** The runner must safely detect and remove stale symlinks to avoid corrupting a user's real data.
* **Depth & Naming Constraints:** To keep discovery simple and reliable, the runner restricts search depth for package IDs and requires certain naming patterns when placed inside subfolders.
* **Application-Specific Behavior:** Some apps store state in unexpected places (e.g., system caches, hardware-specific directories). The approach documents known exceptions and suggests workarounds.
* **Compatibility:** Not all packages or applications will behave identically across desktop environments; some manual adjustments may be necessary.
* **Security & Sandboxing:** Redirecting data via symlinks respects the package manager's sandboxing model at the filesystem level, but any approach that changes data paths should be reviewed for sandbox and permission implications.
* **Safe defaults & explicit user action:** Because the mechanism touches user data paths, the runner defaults to `PACKAGE_ID=0` (no action) and an `IGNORE_LIST` to prevent accidental modifications. The user must explicitly set a real `PACKAGE_ID` to enable behavior.
* **Offline installation:** Can work with this method but is limited. The current method relies mostly on downloading packages normally (online) and using symlinks for offloading.
