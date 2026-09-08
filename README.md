# upal
Universal Portable Abstraction Layer

a lightweight middleware engine that decouples application data from the host operating system's rigid file structure. Instead of competing with the host's package manager, it orchestrates it, simulating a self-contained "Windows-style" portable folder while secretly leveraging the host's native tools behind the scenes.

Here is the architectural breakdown of how this abstraction operates:

### 1. The Core Architecture

* **$PORTABLE_ROOT:** To the user, the application is simply a folder containing a executable and your user data . This folder can be moved across drives, partitions, or entirely different operating systems.
* **The Executable:** a single executable acts as a context-aware engine. When clicked, it detects its environment and dynamically routes the application's data from the portable folder to the host operating system before launching the program.
* **Package Manager Agnosticism:** The abstraction layer buy default doesn't care how the binary is obtained. It can trigger a Flatpak installation, use the distro's native package manager (like APT, DNF, or pacman), fetch a GitHub release, compile from source with pkgit or simply extract a tarball. The installation backend is completely abstracted away from the user experience.

### 2. Dependency & Data Handling

* **Host-Provided Binaries:** Unlike heavy containerized formats like AppImage that bundle every single library, this approach can rely on the host system to provide the heavy lifting. By default the OS manages the binaries, while the portable directory manages the identity and state of the app.
* **Isolated User Data:** The true portability lies in the user data. The engine intercepts where the application naturally wants to save its data (e.g., `~/.config`, `~/.local/share`, or `~/.var/app/`) and forces it into the portable directory. This is typically achieved via dynamic symlinking, environment variable overrides or OS specific features

### 3. Seamless Desktop Integration

* **On-the-Fly Customization:** The moment the runner is executed, it automatically bridges the gap with the host OS. It generates and registers `.desktop` files in the host's application menus, applies custom icons, and maps executables to standard PATH directories.
* **Zero-Friction State Management:** Because all configurations, layouts, plugins, and save states live inside the portable root, the host OS is treated as a disposable compute node. If you move the portable folder to a new machine, your exact workspace is instantly restored.

This approach essentially takes the absolute best part of Windows portable apps—the unified data directory—and marries it to the security and dependency management of modern Linux package ecosystems.
