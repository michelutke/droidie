# Droidie

macOS menu bar app for transferring files to/from Android devices over adb — USB or wireless debugging. No Android Studio needed.

## Features

- Live device list (USB + WiFi) via adb track-devices
- Drag & drop files onto the popover or the menu bar icon → push to device
- Browse device storage and pull files to the Mac — or drag files straight out into Finder
- In-app wireless-debugging pairing (IP:port + pairing code)
- Transfer progress, media scan broadcast so photos/videos show up in the gallery

## Requirements

- macOS 14+
- adb: `brew install android-platform-tools`
- Phone: Developer options → USB debugging (USB) or Wireless debugging (WiFi)

## Build

    swift build            # debug build
    swift test             # run tests
    ./scripts/make-app.sh  # produces dist/Droidie.app

## Wireless pairing

1. Phone: Settings → Developer options → Wireless debugging → "Pair device with pairing code"
2. Droidie: device row → "+ Pair", enter the pairing IP:port + 6-digit code, plus the
   connect IP:port shown on the main Wireless debugging screen.
3. Droidie remembers the endpoint; use "⟳ Reconnect" next time.

## Settings

- Device destination folder (default `/storage/emulated/0/Download`)
- Mac download folder (default `~/Downloads`)
- adb path override (default: auto-detect homebrew/PATH)

## Manual E2E checklist

- [ ] USB: plug in → device appears green within ~1 s; unplug → disappears
- [ ] Push photo via drop zone → progress → gallery shows it
- [ ] Push folder → arrives recursively
- [ ] Push file with spaces/umlauts in name
- [ ] Icon drop (no popover) → lands in default folder
- [ ] Browse: navigate, pull 2 files → in ~/Downloads
- [ ] Browse: drop file → lands in viewed folder
- [ ] Pair over WiFi, transfer, toggle WiFi off mid-transfer → row fails with error, retryable
- [ ] Unauthorized state shows hint, clears after phone confirm
- [ ] Device full / permission-denied push → red row with adb error
