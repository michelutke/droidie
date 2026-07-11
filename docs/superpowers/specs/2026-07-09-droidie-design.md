# Droidie — Design Spec

**Date:** 2026-07-09
**Status:** Approved for planning

## Purpose

macOS menu bar app to transfer files between Mac and Android devices (primary: Pixel 8 Pro) over adb — USB or wireless debugging. Replaces flaky third-party transfer tools (Quick Share unavailable, Blip unreliable). Works fully standalone, no Android Studio.

## Requirements

- Detect and list connected adb devices live (USB + WiFi), selectable.
- Drag & drop files/folders from Finder → push to selected device.
- Pull files from device via simple file browser pane.
- In-app wireless-debugging pairing (IP:port + 6-digit code).
- Per-file transfer progress.
- Media scan broadcast after push so media appears in Gallery/Photos.
- Configurable default destination folder on device (default `/sdcard/Download`).

## Architecture

Swift/SwiftUI menu bar app (`NSStatusItem` + popover), macOS 14+, `LSUIElement` (no dock icon). Name: **Droidie**.

adb integration is **hybrid (option C)**:
- **Subprocess** for all actions: `adb push`, `pull`, `pair`, `connect`, `shell ls`, via `Process`. adb binary resolution: bundled copy → `/opt/homebrew/bin/adb` → `PATH` → user-set path (setting).
- **Direct socket** only for device tracking: `NWConnection` to `localhost:5037`, request `host:track-devices-l` → streamed live device add/remove/state events. No polling. If server not running, spawn `adb start-server` first; reconnect with backoff if socket drops.

### Components

| Component | Responsibility |
|---|---|
| `AdbService` | Subprocess execution + 5037 track-devices socket. Owns adb path resolution. |
| `TransferQueue` | Serial job queue (push/pull). Parses `[ 42%]` progress lines. Triggers media scan after push. |
| `DeviceStore` | Observable device state: serial, model, transport (usb/tcp), state (device/unauthorized/offline). Remembered wireless IPs in UserDefaults for one-click reconnect. |
| UI | Popover: device row, Send/Browse tabs, pairing sheet, settings. |

Storage: UserDefaults only (settings + remembered IPs). No DB, no daemon, no credentials — adb server owns auth state.

## UI

**Popover:**
- **Device row (top):** dropdown of devices (`Pixel 8 Pro · USB`). Status dot: green=ready, yellow=unauthorized (hint "confirm on phone"), grey=offline. `+ Pair` button; `⟳ Reconnect` next to remembered-offline WiFi devices (`adb connect`).
- **Send tab:** large drop zone. Dropped files/folders → transfer list rows: filename, size, progress bar, cancel. Done rows ✓, auto-clear ~10 s. Menu bar icon reflects overall progress.
- **Browse tab:** breadcrumb path from `/sdcard`, folder listing via `adb shell ls -la`, multi-select, `Save to Mac` → default Mac dir (setting, default `~/Downloads`). Drops onto Browse tab push into currently viewed folder (ad-hoc destination override).
- **Bottom bar:** settings, quit.

**Pairing sheet:** fields for `IP:port` + 6-digit code (from phone's Wireless debugging screen) → `adb pair`, then `adb connect` to connect-port (prompt for it; mDNS auto-fill only if trivial). Save IP for reconnect.

**Drag onto menu bar icon:** accepted directly → push to selected device's default folder without opening popover.

**Settings:** default device destination path, default Mac download dir, adb binary path override.

## Transfer behavior

- `adb -s <serial> push <local> <remote>/`; folder drop = one recursive push. Jobs run serially.
- Progress from adb's `[ NN%]` stdout lines; if absent, indeterminate bar.
- After push of media files (image/video/audio extensions): `adb shell cmd media scan <remote-path>`.
- Remote paths quoted; spaces/unicode-safe.

## Error handling

| Failure | Behavior |
|---|---|
| adb binary missing | Onboarding screen: install hint (`brew install android-platform-tools`) + manual path picker. |
| Device unauthorized | Inline hint; auto-refresh on track-devices event when user confirms on phone. |
| Push/pull failure (full disk, permissions) | Row turns red with adb stderr text + retry button. |
| WiFi drop mid-transfer | Job fails with retry; reconnect button on device row. |
| 5037 socket drop | Auto `adb start-server` + reconnect with backoff. |

## Testing

- **Unit:** stdout parsers (track-devices payload, progress lines, `ls -la` output), remote path quoting. Pure functions.
- **Integration:** `AdbService` against fake `adb` shell-script fixture emitting canned output.
- **Manual/E2E:** real Pixel 8 Pro over USB and WiFi; checklist in README.

## Out of scope (v1)

Thumbnails in browser, parallel multi-device transfers, APK install special-casing, auto-update, drag-out from Browse tab to Finder.
