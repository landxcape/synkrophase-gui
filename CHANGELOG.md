# Changelog

All notable changes to Synkrophase GUI are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-10-19

### Added
- **In-App About Section & GitHub Update Checker (`AboutView.swift`, `UpdateChecker.swift`)**:
  - Implemented `@Observable` update checker querying GitHub Releases API with automated semver comparison.
  - Added dedicated About view displaying app icon, dynamic bundle version, core daemon engine info (`synkro v0.8.2`), license, and project links.
  - Interactive update flow: detects newer releases, provides 1-click **"Copy brew upgrade"** button (`brew upgrade --cask synkrophase`), and direct link to GitHub release.
  - Integrated `[ⓘ]` About button in the Menu Bar popover utility footer with animated in-place crossfade and dynamic height recalculation.
- **Release CI Quality Gate**:
  - Added mandatory `test-gate` job in `.github/workflows/release.yml` executing `swift test` on macOS runners before building or publishing release assets.

## [0.1.1] - 2026-10-19

### Added
- **Native Application Icon (`AppIcon.icns`)**:
  - Implemented authentic, minimal Apple Pro audio design language icon (Dual-Track Synchronized Waveform).
  - Deep midnight-indigo squircle with 185pt Apple continuous corner radius, subtle inset acoustic plate, and dual synchronized audio waveform peaks converging into a pure white master clock pulse.
  - Multi-resolution Retina icon assets generated from 16×16 up to 1024×1024.

## [0.1.0] - 2026-10-19

### Added
- **Native macOS Menu Bar Application (`macos/`)**:
  - Implemented standalone Menu Bar Extra popover in Swift 6.4 and SwiftUI with `.accessory` activation policy (zero Dock presence).
  - Integrated native behind-window liquid glass optical transparency using `NSVisualEffectView` with `.popover` material, `.behindWindow` blending, clear window backing, and 16pt continuous corner clipping.
  - Added dynamic window frame expansion engine (`DynamicWindowResizer` + `ContentHeightPreferenceKey`) that calculates internal SwiftUI content height and smoothly animates the window frame downwards from the status bar anchor.
  - Implemented uncropped 1:1 menu bar status item icons with semantic `waveform.slash` indicator when offline/disconnected and variable-color animated `waveform` during active playback.
- **Real-Time Playback & Transport Controls**:
  - Active track card with artwork thumbnail, title, artist, album, and player source badge (`Spotify` or `Apple Music`).
  - Interactive playback timeline scrubber with microsecond-resolution clock drift offset indicator.
  - Transport buttons: Play/Pause toggle, Next track, Previous track, and synchronized volume level slider.
- **Hierarchical Room & Role Management**:
  - Room status header displaying active room code, LAN connection status, and PTP-lite network synchronization metrics.
  - Granular 3-tier role badges: `[LEADER]` (room reference), `[MODERATOR]` (playback controls), and `[LISTENER]` (synchronized follower).
  - Expandable Connected Peers drawer listing LAN participants with live peer offsets and assigned roles.
- **Zero-Touch Daemon Management & Offline Flow**:
  - Dedicated offline state interface featuring dual one-click actions: Host a new room or Join by room code.
  - Background supervisor automatically verifies daemon socket readiness at `~/.synkro/synkro.sock` and spawns `synkro daemon start` if offline.
- **Streaming Event-Driven IPC Client (`DaemonIpcClient`)**:
  - Non-blocking asynchronous event reader utilizing Apple's `DispatchSourceRead` on a serial queue.
  - Real-time deserialization of length-prefixed JSON-RPC command responses and push event streams (`peer_update`, `playback_update`, `drift_update`).
- **Developer & CI/CD Tooling**:
  - Automated application packaging script (`package_app.sh`) generating ad-hoc codesigned `Synkrophase.app` bundles.
  - GitHub Actions CI workflow verifying test suites and bundle packaging on macOS runners.
  - Automated GitHub Actions release pipeline archiving application zips with SHA-256 checksums on version tags.
  - Multi-platform architectural contract and wire protocol manual (`doc/CLIENT_ARCHITECTURE.md`).
