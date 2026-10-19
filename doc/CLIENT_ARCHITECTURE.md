# Synkrophase GUI Client Architecture & Protocol Specification

## 1. Scope & Inception Intent

This document serves as the canonical technical architectural specification for all **Synkrophase Graphical User Interface (GUI) clients**. Regardless of target operating system or frontend technology stack (e.g. macOS SwiftUI, Linux GTK4, or Windows WinUI), every GUI client is an external presentation and control surface that attaches to the authoritative Synkrophase background daemon.

### Core Architectural Invariants:
1. **Decoupled Lifecycle**: The GUI is an ephemeral client. The daemon runs the low-level PTP clock synchronization and UDP network engine independently. Launching, closing, or crashing the GUI must never disrupt an active audio session.
2. **Single Source of Truth**: The GUI maintains zero independent network synchronizer state. All timeline positions, track identities, room memberships, and peer roles stream directly from the daemon.
3. **Idiomatic Layering**: Every client implementation must maintain clean separation of concerns:
   - `Transport Layer`: Asynchronous socket framing and reconnect backoff.
   - `Protocol Layer`: Type-safe serialization and deserialization of requests and events.
   - `Store / ViewModel Layer`: Reactive state management reconciling optimistic UI actions with daemon events.
   - `Presentation Layer`: Platform-native, lightweight, dockless system tray / menu bar popover components.
4. **Footprint Budget**: Designed to run 24/7 in the system tray without user friction ($\le 25\text{MB}$ RAM idle, $0.0\%$ CPU when popover is closed, instant wake on click).

---

## 2. IPC Wire Protocol & Transport Contract

Clients connect to the local daemon via an asynchronous bidirectional stream:
- **macOS / Linux**: Unix domain socket located at `~/.synkrophase/synkro.sock`.
- **Windows**: Named pipe located at `\\.\pipe\synkrophase-synkro.sock` (once supported).

### 2.1 Message Framing
All messages across the socket are **Newline-Delimited JSON (NDJSON)** encoded in UTF-8. Every request, response, and event must terminate with a single newline (`\n`).

### 2.2 Client Requests (`IpcRequest`)
```json
{
  "id": 1,
  "method": "play",
  "params": {}
}
```
- `id` *(optional integer)*: Client-assigned correlation ID. If present, the daemon responds with matching ID.
- `method` *(string, required)*: The command to invoke.
- `params` *(object, optional)*: Method-specific parameters.

### 2.3 Daemon Responses (`IpcResponse`)
```json
{
  "id": 1,
  "result": { "success": true },
  "error": null
}
```
If an error occurs:
```json
{
  "id": 1,
  "result": null,
  "error": {
    "code": 400,
    "message": "Volume level must be between 0 and 100"
  }
}
```

### 2.4 Streaming Push Events (`IpcEvent`)
Upon connection, clients send `{"id": 1, "method": "subscribe"}`. The daemon immediately streams real-time updates as JSON objects:
```json
{
  "event": "playback_update",
  "data": { ... }
}
```

---

## 3. Supported Methods & Event Schemas

### 3.1 Client Methods Reference

| Method | Parameters | Description |
| :--- | :--- | :--- |
| `subscribe` | *None* | Registers client socket for push event stream. Daemon activates 200ms periodic status broadcasts. |
| `status` | *None* | Fetches complete `DaemonStatusSnapshot`. |
| `play` | *None* | Requests playback resumption room-wide. |
| `pause` | *None* | Requests playback pause room-wide. |
| `resume` | *None* | Alias for `play`. |
| `next` | *None* | Skips to next track. |
| `prev` | *None* | Skips to previous track. |
| `seek` | `{"position_sec": 45.5}` | Seeks room playback to target position in seconds. |
| `volume` | `{"level": 80}` | Sets room volume (0–100) or mirrors host volume if omitted. |
| `transfer` | `{"target": "uuid-or-name"}` | Hands over room leadership to specified peer. |
| `assign_role`| `{"target": "uuid-or-name", "role": "moderator"}` | Sets peer role (`leader`, `moderator`, `listener`). |
| `chat` | `{"message": "Hello!"}` | Broadcasts a chat message to the room. |
| `shutdown` | *None* | Cleanly terminates the background daemon. |

### 3.2 Push Event Reference

#### A. `playback_update`
Emitted whenever native player state or position updates (streamed every 200ms or instantly on player actions):
```json
{
  "event": "playback_update",
  "data": {
    "is_playing": true,
    "position_us": 45500000,
    "rate": 1.0,
    "metadata": {
      "title": "Song Title",
      "artist": "Artist Name",
      "album": "Album Name",
      "duration_us": 210000000
    }
  }
}
```

#### B. `peer_update`
Emitted on peer join, heartbeat update, role change, or departure:
```json
{
  "event": "peer_update",
  "data": [
    {
      "device_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "name": "MacBook-Pro",
      "role": "Leader",
      "clock_offset_us": 0,
      "last_seen_epoch_ms": 1729312000000
    }
  ]
}
```

#### C. `drift_update`
Emitted with microsecond timeline drift reconciliation metrics:
```json
{
  "event": "drift_update",
  "data": {
    "offset_us": 120,
    "status": "InSync",
    "target_position_us": 45500120,
    "measured_position_us": 45500000
  }
}
```

#### D. `network_update`
Emitted with PTP clock network telemetry:
```json
{
  "event": "network_update",
  "data": {
    "rtt_us": 850,
    "jitter_us": 45,
    "sync_uncertainty_us": 20
  }
}
```

---

## 4. Universal Layered Client Architecture

Every GUI client implementation must maintain the following four tiers:

```text
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│   (MenuBarExtra / Popover / StatusIcon / ControlViews) │
└───────────────────────────┬────────────────────────────┘
                            │ observes / dispatches
┌───────────────────────────▼────────────────────────────┐
│                    ViewModel / Store                   │
│       (Reactive State, Optimistic Timeline Trackers)   │
└───────────────────────────┬────────────────────────────┘
                            │ commands / event callbacks
┌───────────────────────────▼────────────────────────────┐
│                  DaemonIpcClient Service               │
│        (Connection Lifecycle, Buffer Framing, Backoff) │
└───────────────────────────┬────────────────────────────┘
                            │ newline-delimited JSON
┌───────────────────────────▼────────────────────────────┐
│               OS IPC Transport (Unix Socket)           │
│                ~/.synkrophase/synkro.sock              │
└────────────────────────────────────────────────────────┘
```

### Tier 1: Transport & Connection State Machine
The client must maintain a deterministic connection state:
- **`Disconnected`**: Daemon socket does not exist or daemon is stopped.
- **`Connecting`**: Socket connection attempt in progress.
- **`Connected`**: Socket active, `subscribe` acknowledged, event loop streaming.
- **`Reconnecting`**: Transient disconnection detected; client attempts reconnection with exponential backoff ($500\text{ms} \to 1\text{s} \to 2\text{s} \dots \text{max } 5\text{s}$).

### Tier 2: State Store & Reconciliation
- **Optimistic Scrubbing**: When the user drags the timeline seek bar, the UI immediately reflects the new position and dispatches `seek`. Authoritative `playback_update` reconciliation confirms or snaps the position after actuation.
- **Continuous Timeline Interpolation**: Between 200ms `playback_update` packets, when `is_playing == true`, the client smoothly advances local playback display time using monotonic OS clocks (`std::time::Instant` or `ContinuousClock`).

### Tier 3: UI Component Hierarchy
The standard popover window ($\approx 320\text{px} \times 280\text{px}$) consists of:
1. **Dynamic Menu Bar Icon**:
   - `waveform` animation when playing in sync.
   - `waveform.slash` when paused.
   - Warning badge when daemon is offline or drift $> 50\text{ms}$.
2. **Room & Role Header**:
   - Room Code with click-to-copy button.
   - User Role badge (`Leader`, `Moderator`, `Listener`).
   - Connected peer count pill.
3. **Now Playing Card**:
   - Track title and artist with smooth text truncation.
   - Player badge (Spotify / Apple Music).
4. **Timeline Scrubber**:
   - Current elapsed / total duration.
   - Interactive seek slider (role-gated: disabled for read-only `Listener`).
5. **Playback Controls**:
   - Previous, Play/Pause, Next.
   - Room volume slider.
6. **Peer Drawer (Collapsible)**:
   - Live peer list with individual clock offsets and role badges.
7. **Offline Empty State**:
   - Displayed when connection state is `Disconnected`.
   - Displays clear "Synkrophase Daemon Offline" message with a one-click "Start Daemon" trigger (`synkro daemon start`).

---

## 5. Cross-Platform Idiomatic Implementation Matrix

| Architectural Role | macOS Native (Swift) | Linux Native (GTK4 / C or Rust) | Windows Native (C# / WinUI) |
| :--- | :--- | :--- | :--- |
| **Language & Framework** | Swift 5.9+ / SwiftUI | Rust or C / GTK4 + Libadwaita | C# / WinUI 3 (.NET 8+) |
| **Menu Bar / System Tray**| `MenuBarExtra(style: .window)` | `StatusNotifierItem` (D-Bus) | `TaskbarIcon` (HwndSource) |
| **Transport Implementation** | `Network.framework` (`NWConnection`) | `Gio.SocketClient` (`UnixSocketAddress`) | `NamedPipeClientStream` |
| **Reactive State Pattern**| `@Observable` / `@Published` | `GObject` properties / signals | `ObservableObject` / `INotifyPropertyChanged` |
| **Concurrency Model** | Swift Structured Concurrency (`async/await`, `Task`) | Tokio async tasks / GLib MainLoop | async / await (`Task`) |
| **JSON Serialization** | Swift `Codable` structs | `serde_json` or `json-glib` | `System.Text.Json` |

---

## 6. Modern Platform UI & Design Standards

Every GUI client must adhere strictly to the modern design standards of its target operating system. Clients must never regress to outdated, boxy, or unstyled legacy desktop controls.

### 6.1 macOS (Current: macOS 26 / 27 Apple HIG)
- **Materials & Geometry**:
  - Glass dynamism: Use `.ultraThinMaterial` and `.regularMaterial` to sample desktop wallpaper tones naturally.
  - Continuous corner radius geometry: `RoundedRectangle(cornerRadius: 16, style: .continuous)`.
  - Inner boundary stroke: `0.5pt` specular stroke (`Color.white.opacity(0.12)`) replacing blunt drop shadows.
- **Menu Bar Item**:
  - Template image rendering (monochrome with alpha channels, 24pt standard height) ensuring automatic adaptation to light, dark, and active click highlights.
  - SF Symbols with animated variable color effects (`.symbolEffect(.variableColor.iterative)`) when actively synchronizing.
- **Micro-Interactions & Controls**:
  - Control Center-style capsule sliders for volume and timeline scrubbing.
  - Interactive spring physics (`.spring(response: 0.25, dampingFraction: 0.7)`).
  - High-precision monospaced numeric styling (`.monospacedDigit()`) for latency, drift, and time counters to eliminate digit-ticking jitter.
- **Responder Invariants**:
  - No nested `.sheet()` or secondary modal popovers inside `MenuBarExtra(style: .window)`. Subviews must swap dynamically inline within the root view container to preserve click-outside auto-dismissal.

### 6.2 Linux (Modern GNOME 47+ / KDE Plasma 6+)
- **Materials & Geometry**:
  - Libadwaita / Breeze flat surfaces with soft ambient depth and 12px rounded cards.
- **System Tray Protocol**:
  - Modern FreeDesktop `StatusNotifierItem` (SNI) protocol over D-Bus (`org.kde.StatusNotifierItem`). Replaces legacy XEmbed system trays across Wayland and X11 compositors.
  - Symbolic SVG icons (`-symbolic.svg`) dynamically inheriting desktop theme color accents.
- **Media Controls**:
  - MPRIS D-Bus player controls integrated with native AdwSlider and AdwHeaderBar widgets.

### 6.3 Windows (Windows 11 / Modern Fluent)
- **Materials & Geometry**:
  - Mica material for window backgrounds (sampling desktop wallpaper) and Acrylic blur for popovers.
  - 8px–12px rounded geometry and 1px border stroke (`SystemFillColorNeutralBackgroundBrush`).
- **Taskbar System Tray**:
  - Windows App SDK / WinUI 3 `TaskbarIcon` flyout anchored cleanly above the taskbar chevron.
  - Segoe Fluent Icons with tactile hover states.
