# Nautilus application bundles

## Goal

Double-click a portable folder and launch it, the way a macOS `.app` works. Normal directories must keep opening for browsing.

This is the last piece of the "one folder is the app" idea. The runner already owns the data and the launch logic; this makes the folder itself the entry point in the file manager.

## Decision

Opt-in, not universal. Only a directory with an explicit manifest is an application bundle. A global Nautilus preference controls the feature:

- default: ask before the first launch of a bundle;
- downloaded or extracted bundles: always confirm, even when the preference allows local bundles;
- the feature can be disabled entirely;
- an invalid manifest falls back to opening the directory and reports the error.

A directory containing `run.sh` is not enough. The manifest is the declaration of intent.

## Manifest

The name is provisional; `application.json` is the current proposal.

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

Rules:

- `entry` must be a relative path inside the bundle.
- Reject absolute paths, `..`, and symlinks that escape the root.
- The entry must be executable.
- The manifest is optional desktop integration, like the icon and `.desktop` file. It is not a second manager; `runner` remains the only file that manages the app.

## Why not a Nautilus extension

The public `libnautilus-extension` API exposes menu, info, property, and column providers. It has no hook for replacing directory activation. An extension can add a right-click "Run as application" item, which is useful as a prototype of the bundle format, but it cannot change double-click behavior.

A generic `NautilusActivationProvider` API would solve this for every application, but it needs conflict rules, priorities, and a stable public interface. That is a later project, not the first implementation.

## Routes

| Route | Effort | Verdict |
|---|---|---|
| Nautilus extension | low | Insufficient for double-click; good for a context-menu prototype |
| Patch Nautilus in a fork | medium | Chosen: fastest path to the real interaction |
| Upstream merge request | high | Best long-term outcome, after a prototype and discussion |
| New activation-provider API | very high | Later, if other applications need it |

## Implementation plan

1. Clone and build Nautilus unmodified.
2. Trace the directory activation path. Start with `src/nautilus-files-view.c`, `src/nautilus-file.c`, `src/nautilus-mime-actions.c`, and `src/nautilus-window-slot.c`.
3. Build a minimal proof of concept with a hardcoded manifest.
4. Split the code into detection, resolution, and execution.
5. Add the preference, trust confirmation, path validation, and error handling.
6. Test in a separate GNOME environment, not by replacing the system Nautilus.
7. Open a GNOME Discourse discussion with screenshots and a working demo.
8. If maintainers are interested, submit a merge request.

Keep a `directory-apps` branch rebased on upstream `main` so the feature stays isolated.

## Source investigation

```bash
git clone https://gitlab.gnome.org/GNOME/nautilus.git
cd nautilus

rg -n "activate_files|activate_file" src/
rg -n "open_location|open.*directory" src/
rg -n "nautilus_mime_activate" src/
rg -n "G_FILE_TYPE_DIRECTORY" src/
rg -n "g_file_query_info|standard::type" src/
rg -n "gtk.*activate|activate.*item" src/
```

The activation path is asynchronous. The patch must follow the existing error handling and cancellation conventions instead of blocking the main loop.

## Open questions

- Manifest name and format: `application.json` versus a hidden `.directory-app`.
- Whether the existing `.desktop` file can serve as the manifest instead of adding a new file.
- Preference default: ask on first launch versus off until enabled.
- Trust model for local folders, downloaded archives, and network mounts.
- Whether upstream GNOME considers this a file-manager feature or a desktop-environment feature.

## References

- Nautilus source: <https://gitlab.gnome.org/GNOME/nautilus>
- Nautilus extension API: <https://gnome.pages.gitlab.gnome.org/nautilus/>
- GIO documentation: <https://docs.gtk.org/gio/>
- GNOME Discourse, Applications: <https://discourse.gnome.org/c/applications/7>
- Nautilus issues: <https://gitlab.gnome.org/GNOME/nautilus/-/issues>
