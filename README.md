# Synkrophase GUI

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg)](#license)

Native graphical frontend clients for [Synkrophase](https://github.com/landxcape/synkrophase) — a high-precision, low-latency playback controller synchronizer for local networks.

---

## Architecture Overview

Synkrophase GUI applications are lightweight presentation clients that interface directly with the background `synkro` daemon over a local IPC stream. Rather than bundling internal synchronization engines, each GUI client connects via Unix Domain Socket (`~/.synkro/synkro.sock`) or platform-native IPC to command the daemon and consume real-time playback state updates.

Detailed protocol specifications, frame definitions, and state machine transitions are documented in [CLIENT_ARCHITECTURE.md](doc/CLIENT_ARCHITECTURE.md).

```text
┌──────────────────────────────────────────────┐
│  Native GUI Client (macOS / Linux / Windows) │
└──────────────────────┬───────────────────────┘
                       │ JSON-RPC IPC Stream
                       ▼
┌──────────────────────────────────────────────┐
│  Background Engine (synkro daemon)           │
│  • PTP-lite Clock Sync (UDP)                 │
│  • Player Adapters (Spotify / Apple Music)   │
│  • Actuation Latency Profiling               │
└──────────────────────────────────────────────┘
```

---

## Platform Clients

| Platform | Frontend Stack | Interface Form Factor | Status |
| :--- | :--- | :--- | :--- |
| **macOS** | Swift 6.4 / SwiftUI | Native Menu Bar Extra Popover | **Available** (`macos/`) |
| **Linux** | GTK4 / Libadwaita / Rust | System Tray Indicator & Window | *Planned* (`linux/`) |
| **Windows** | WinUI 3 / XAML / C# | System Notification Area Flyout | *Planned* (`windows/`) |

---

## macOS Menu Bar App (`macos/`)

The macOS frontend is a native Menu Bar Extra application designed specifically for macOS with:
- **Behind-Window Liquid Glass Transparency**: Native `NSVisualEffectView` materials rendering optical depth and vibrancy against the user's desktop wallpaper.
- **Dynamic Window Resizing**: Smooth animated frame expansion when toggling room member disclosure drawers.
- **Microsecond Clock & Playback Scrubbing**: Real-time progress bar, timeline scrubber, track artwork/metadata, and transport controls.
- **Role Hierarchy Indicators**: Granular peer badges for `[LEADER]`, `[MODERATOR]`, and `[LISTENER]`.
- **Zero-Touch Background Daemon Management**: Automatically triggers background daemon hosting or room joining directly from the menu bar when offline.

### Prerequisites

- macOS 14.0 (Sonoma) or newer (optimized for modern macOS 27 SDK)
- Swift 6.0+ toolchain (Xcode 16+)
- Installed `synkro` daemon binary (available via `cargo install --path ../synkrophase` or Homebrew)

### Building and Packaging

1. **Build Debug Binary**:
   ```bash
   cd macos
   swift build
   ```

2. **Run Test Suite**:
   ```bash
   swift test
   ```

3. **Package Native Application Bundle (`Synkrophase.app`)**:
   ```bash
   ./scripts/package_app.sh
   ```
   The self-contained, ad-hoc codesigned application bundle will be created at `macos/dist/Synkrophase.app`.

4. **Launch Application**:
   ```bash
   open dist/Synkrophase.app
   ```

---

## Contributing

Contributions for additional native platform implementations (such as Linux GTK4 and Windows WinUI) are welcome. Please ensure new frontend clients adhere strictly to the IPC state machine and wire models documented in [CLIENT_ARCHITECTURE.md](doc/CLIENT_ARCHITECTURE.md).

---

## License

Synkrophase GUI is dual-licensed under either:

* [Apache License, Version 2.0](LICENSE-APACHE)
* [MIT License](LICENSE-MIT)

at your option.
