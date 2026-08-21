# jbar 🖥️

A simple Windows/GNOME 2 style taskbar for macOS. There are several paid options for this kind of thing but few free ones so this exists to fill that gap for me and to test out a "real" vibe coded application. 

---

## Building & Running

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```

### Build & Launch
```bash
make run        # Builds and launches jbar.app
```

Additional targets:
```bash
make install    # Builds and installs jbar.app to /Applications
make uninstall  # Removes jbar.app from /Applications
make app        # Builds signed release application bundle (build/jbar.app)
make universal  # Builds universal binary (Apple Silicon + Intel)
make build      # Compiles debug binary via Swift PM
make clean      # Removes all build artifacts
```

---

## Accessibility Permissions

`jbar` requires macOS Accessibility permissions to inspect and manage running windows:
1. Go to **System Settings > Privacy & Security > Accessibility**.
2. Add/enable **`jbar`**.

---

## Launch at Startup (Optional)

To have `jbar` start automatically upon logging in:
1. Open **System Settings > General > Login Items & Extensions**.
2. Under **Open at Login**, click the **`+`** button.
3. Select **`jbar.app`** (from `/Applications` or your `build/` directory).
