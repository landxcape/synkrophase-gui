# Synkrophase GUI

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg)](#license)
[![macOS: 14.0+](https://img.shields.io/badge/macOS-14.0%20%7C%2027-black?logo=apple)](macos/)
[![Swift: 6.4](https://img.shields.io/badge/Swift-6.4-F05138?logo=swift&logoColor=white)](macos/)
[![Release](https://img.shields.io/github/v/release/landxcape/synkrophase-gui)](https://github.com/landxcape/synkrophase-gui/releases)

**Synkrophase GUI** provides native, platform-integrated graphical frontend clients for [**Synkrophase**](https://github.com/landxcape/synkrophase) — the high-precision, low-latency playback controller synchronizer for local networks.

Rather than streaming heavy audio over the network, Synkrophase coordinates each machine's native desktop player (Spotify, Apple Music) with microsecond monotonic clock alignment. This repository hosts the official native frontend applications that interact with the headless `synkro` background daemon via local IPC.

---

## Visual Interface (macOS Menu Bar)

The macOS client lives natively in the status bar as a Menu Bar Extra popover built with Swift 6 and SwiftUI:

```text
       ┌──────────┐
───────┤    ∿∿    ├───────────────────────────────────────────────── (Menu Bar)
       └────┬─────┘
            ▼
┌────────────────────────────────────────────────────────┐
│  ROOM: TESTROOM               • LAN Connected          │
│  Role: [LEADER]               • Offset: +12µs (<80ms)  │
├────────────────────────────────────────────────────────┤
│  ┌──────────┐  Numb                                    │
│  │  ALBUM   │  Linkin Park — Meteora                   │
│  │   ART    │  [Spotify]                               │
│  └──────────┘                                          │
│                                                        │
│  01:05 ━━━━━━━━━━━━━━━━━━●───────────────────── 03:07   │
│                                                        │
│     [⏮]             [⏸] / [▶]             [⏭]         │
│     Prev           Play / Pause           Next         │
│                                                        │
│  Volume: ━━━━━━━━━━━━━━━━━━━━━━●─────── (82%)          │
├────────────────────────────────────────────────────────┤
│  ▼ Connected Peers (2)                                 │
│    • Host (You)                [LEADER]       Ref Clock │
│    • Follower-Mac              [MODERATOR]        +12µs │
├────────────────────────────────────────────────────────┤
│  [↻ Refresh]    [⏻ Stop Daemon]            [Quit App]  │
└────────────────────────────────────────────────────────┘
```

When disconnected, the popover transitions seamlessly into an offline quick-launch hub:

```text
┌────────────────────────────────────────────────────────┐
│  ∿/  Synkrophase is Offline                            │
│      No active room session running                    │
├────────────────────────────────────────────────────────┤
│  Host a Room                                           │
│  Start a new local network session as room leader      │
│  [ Host New Room ]                                     │
├────────────────────────────────────────────────────────┤
│  Join a Room                                           │
│  Enter an existing 4-letter room code                  │
│  [ Room Code: ABCD ]   [ Join Room ]                   │
├────────────────────────────────────────────────────────┤
│  [↻ Refresh]                               [Quit App]  │
└────────────────────────────────────────────────────────┘
```

---

## Core Features & Design Highlights

- **Native Behind-Window Liquid Glass Transparency**:
  - Leverages AppKit's `NSVisualEffectView` with `.behindWindow` blending mode and `.popover` material.
  - Dynamically clears window backing opacity (`window.isOpaque = false`, `window.backgroundColor = .clear`) to create authentic optical refraction blurring your desktop wallpaper with zero artificial borders or heavy gray panels.
- **Dynamic Content Height Expansion**:
  - Eliminates static window frame clipping. As room disclosure drawers (such as the Connected Peers list) expand or collapse, the popover measures internal SwiftUI content height and smoothly animates the AppKit window frame downwards from the menu bar anchor.
- **Uncropped 1:1 Status Bar Indicator**:
  - Clean SF Symbol integration featuring `waveform.slash` when offline/disconnected and real-time variable-color animated `waveform` during active playback, perfectly proportioned to the 22pt macOS status bar bounds.
- **Non-Blocking Streaming IPC Engine**:
  - Replaces traditional blocking POSIX reads with Apple's `DispatchSourceRead` event dispatch on a dedicated serial queue.
  - Ingests real-time JSON-RPC daemon state snapshots and timeline broadcasts without blocking the main rendering thread.
- **Zero-Touch Daemon Management**:
  - Directly launches and supervises the background `synkro` daemon if it is not already running when you click Host or Join.
- **Granular 3-Tier Role Badges**:
  - Real-time visual distinction between `[LEADER]` (room authority and clock reference), `[MODERATOR]` (playback queue control), and `[LISTENER]` (synchronized follower).

---

## Multi-Platform Roadmap

| Platform | Interface | Technology Stack | Status | Directory |
| :--- | :--- | :--- | :---: | :--- |
| **macOS** | Menu Bar Extra Popover | Swift 6.4 / SwiftUI / AppKit | **Available** | [`macos/`](macos/) |
| **Linux** | AppIndicator & Floating Window | GTK4 / Libadwaita / Rust | *Planned* | `linux/` |
| **Windows** | System Notification Area Flyout | WinUI 3 / XAML / C# | *Planned* | `windows/` |

---

## Getting Started (macOS)

### Option A: Homebrew Cask (Recommended)

Homebrew Cask installs **both** the native Menu Bar application (`Synkrophase.app` in `/Applications`) and automatically pulls in the underlying `synkro` background daemon (`/opt/homebrew/bin/synkro`) as a required dependency:

```bash
# 1. Tap the repository
brew tap landxcape/tap

# 2. Install Native Menu Bar App AND CLI Daemon:
brew install --cask landxcape/tap/synkrophase
```

> **Terminal-Only Users**: If you only want the command-line interface, interactive TUI, and headless background engine without the GUI app, install the formula alone:
> ```bash
> brew install landxcape/tap/synkrophase
> ```

### Option B: Download Pre-Built Application Bundle

1. Download the latest `Synkrophase-macos-arm64.zip` from [GitHub Releases](https://github.com/landxcape/synkrophase-gui/releases/latest).
2. Unzip and move `Synkrophase.app` to your `/Applications` directory.
3. Ensure the core `synkro` daemon is installed (`brew install landxcape/tap/synkrophase` or built from source via [`landxcape/synkrophase`](https://github.com/landxcape/synkrophase)).
4. Launch `Synkrophase.app`. The waveform icon will appear in your top Menu Bar.

### Option C: Build from Source

Requires the Swift 6 toolchain (Xcode 16+ or Command Line Tools):

```bash
# 1. Clone the GUI repository
git clone https://github.com/landxcape/synkrophase-gui.git
cd synkrophase-gui/macos

# 2. Run unit and serialization tests
swift test

# 3. Package the native release application bundle
./scripts/package_app.sh

# 4. Launch the application
open dist/Synkrophase.app
```

The packaging script will compile the release binary, generate the `Info.plist` bundle metadata (`LSUIElement = true` for background menu bar activation policy), and apply an ad-hoc code signature to `macos/dist/Synkrophase.app`.

---

## IPC Architecture & Protocol Integration

Synkrophase GUI operates purely as an IPC client. All PTP-lite UDP network packets, clock synchronizations, and player actuation latency profiles are managed by the core Rust daemon.

```text
┌─────────────────────────────────────────────────────────────┐
│                       Synkrophase GUI                       │
│  ┌──────────────────────┐        ┌───────────────────────┐  │
│  │ SwiftUI Popover View │ ◄────► │ SynkroViewModel       │  │
│  └──────────────────────┘        └───────────┬───────────┘  │
│                                              │              │
│                                  ┌───────────▼───────────┐  │
│                                  │ DaemonIpcClient       │  │
│                                  │ (DispatchSourceRead)  │  │
│                                  └───────────┬───────────┘  │
└──────────────────────────────────────────────┼──────────────┘
                                               │ Unix Domain Socket
                                               │ ~/.synkro/synkro.sock
                                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    synkro daemon (Core)                     │
│  • PTP-lite Network Clock Engine (<80ms sync deadband)      │
│  • Single-Flight Player State Evaluator (Spotify / Music)   │
│  • Actuation Latency Profiler & Ahead-of-Time Pre-Dispatch  │
└─────────────────────────────────────────────────────────────┘
```

### IPC Command & Event Contract

- **Socket Location**: `~/.synkro/synkro.sock` (macOS/Linux) or `\\.\pipe\synkro.sock` (Windows).
- **Format**: Length-prefixed JSON frames (`u32` Big-Endian length header + JSON payload).
- **Commands**:
  - `GetStatus`: Retrieves complete snapshot (room code, role, player state, drift metrics, peer table).
  - `Play` / `Pause` / `Toggle`: Controls playback transport.
  - `Seek(position_ms)`: Absolute timeline navigation.
  - `Next` / `Previous`: Track progression.
  - `SetVolume(level)`: Volume alignment.
- **Push Events**: The daemon continuously streams push notifications whenever peers join/leave, track metadata shifts, or roles change without requiring polling.

For the exhaustive specification and schema models, consult [**CLIENT_ARCHITECTURE.md**](doc/CLIENT_ARCHITECTURE.md).

---

## Permissions & Privacy

- **Automation / Apple Events (macOS)**:
  - Controlling playback in Spotify or Apple Music requires granting Automation permissions when prompted by macOS.
  - If a player does not respond, open **System Settings → Privacy & Security → Automation** and verify `Synkrophase.app` has permissions to control **Spotify** and **Music**.
- **100% Local & Private**:
  - Synkrophase communicates strictly over your local Wi-Fi / Ethernet LAN via UDP.
  - Zero cloud dependencies, zero external tracking, zero analytics, and zero external telemetry.

---

## Contributing

We welcome contributions!
- If you'd like to implement the **Linux (GTK4 / Libadwaita)** or **Windows (WinUI 3)** native client, please read [CLIENT_ARCHITECTURE.md](doc/CLIENT_ARCHITECTURE.md) for wire specifications and open an issue or pull request.
- When working on the macOS client, ensure all tests pass (`swift test`) and verify packaging (`./scripts/package_app.sh`) before submitting.

---

## License

Synkrophase GUI is dual-licensed under either:

* **[Apache License, Version 2.0](LICENSE-APACHE)**
* **[MIT License](LICENSE-MIT)**

at your option.
