# Desktop Environment Requirements

This document defines what my desktop environment must provide, extracted from every DE I've used (Hyprland + Wayle, Hyprland + Ambxst, Qtile, GNOME). It is implementation-agnostic — use it as the spec when building or evaluating any new desktop environment.

---

## Core Philosophy

- Tiling layout as default; floating is secondary.
- Wayland-first (X11 as fallback only).
- Unified theming — colors and fonts must come from a single source (Stylix), never hardcoded per app.
- Per-window keyboard layout: US and Hebrew, each window remembers its own layout.
- Idle → dim → lock → sleep pipeline, suppressed during audio playback or fullscreen.
- Minimal, informative status bar.

---

## Display Manager

- A graphical login/session manager is required.
- Must support Wayland sessions.

---

## Window Manager / Compositor

- Tiling layout by default (dwindle or equivalent).
- Split direction preserved across window close.
- Rounded window corners.
- Window open/close/fade/workspace-switch animations.
- Active window has a colored border (accent color from theme); inactive windows have no visible border.
- Small gaps between windows and screen edges.
- 10 named workspaces.
- Wallpaper support (wallpaper set from a central asset, not per-app).
- Multi-monitor support: windows can be moved between monitors; each monitor shows its own workspaces.

---

## Status Bar

- Positioned at the top of the screen.
- Visible on all monitors.
- **Left**: workspace indicator with app icons per workspace.
- **Center**: clock (24-hour format, `HH:MM`).
- **Right**: network status, Bluetooth status, battery level, volume level, power button.
- Network, Bluetooth, battery: icon only (no label), click opens a control dropdown.
- Volume: scrollable from the bar (±2% per scroll tick).
- OSD (on-screen display) for volume and brightness changes.
- A dashboard/launcher button on the left side.

---

## Application Launcher

- Launches apps by name/search (equivalent to dmenu/rofi `-show drun`).
- Triggered by tapping the Super key (release binding).
- Integrated into the bar or accessible from it.
- Includes power actions in the System category: Lock Screen, Logout, Suspend, Hibernate, Restart, Shutdown.

---

## Screen Lock

- Full-screen lock screen on idle, lid close, suspend, and manual trigger.
- Lock screen must display:
  - Current time (large, centered, updates every second).
  - Current date (below time, updates every minute).
  - Password input field (centered, below date).
- Keyboard layout must reset to the first layout (US) when the lock screen appears.
- Bound to `Super + L` and the dedicated laptop lock key (F10 / XF86ScreenSaver).

---

## Idle / Power Pipeline

Timers are cumulative; audio playback and fullscreen suppress the pipeline:

1. **~2.5 min idle** → dim display brightness to 10% (restore immediately on activity).
2. **~5 min idle** → lock screen.
3. **~5.5 min idle** → turn screen off (restore on resume).
4. **~30 min idle** → suspend.

Additional rules:

- On AC power: idle-triggered sleep is suppressed (manual suspend still works).
- On battery: full pipeline applies.
- Lock on lid close and on suspend.

---

## Key Bindings

### Application / Window Management

| Binding                       | Action                       |
| ----------------------------- | ---------------------------- |
| `Super + Return`              | Open terminal                |
| `Super + B`                   | Open browser                 |
| `Super + E`                   | Open file manager            |
| `Super + Q`                   | Close focused window         |
| `Super + F`                   | Toggle fullscreen            |
| `Super + L`                   | Lock screen                  |
| `Super + Super` (tap/release) | Application launcher         |
| `Super + Ctrl + H`            | Focus window left            |
| `Super + Ctrl + J`            | Focus window down            |
| `Super + Ctrl + K`            | Focus window up              |
| `Super + Ctrl + L`            | Focus window right           |
| `Super + Ctrl + Shift + H`    | Move window left             |
| `Super + Ctrl + Shift + J`    | Move window down             |
| `Super + Ctrl + Shift + K`    | Move window up               |
| `Super + Ctrl + Shift + L`    | Move window right            |
| `Super + 1–10`                | Switch to workspace N        |
| `Super + SHIFT + 1–10`        | Move window to workspace N   |
| `Super + SHIFT + Left`        | Move window to left monitor  |
| `Super + SHIFT + Right`       | Move window to right monitor |
| `Super + mouse drag`          | Move floating window         |
| `Super + mouse right-drag`    | Resize window                |
| `Alt + Tab`                   | Window/app overview switcher — visual GUI showing all open windows with their content/icons |

### System Controls

| Binding                 | Action                                           |
| ----------------------- | ------------------------------------------------ |
| `Super + P`             | Open display layout manager                      |
| `Super + V`             | Clipboard history picker                         |
| `Super + ;`             | Emoji picker                                     |
| `Super + SHIFT + S`     | Screenshot (region select, then annotate)        |
| `Super + SHIFT + R`     | Screen recorder                                  |
| `XF86AudioRaiseVolume`  | Volume +5% (repeating, works on lock screen)     |
| `XF86AudioLowerVolume`  | Volume -5% (repeating, works on lock screen)     |
| `XF86AudioMute`         | Toggle mute (works on lock screen)               |
| `XF86AudioMicMute`      | Toggle microphone mute                           |
| `XF86AudioPlay`         | Play / Pause (targets active MPRIS player)       |
| `XF86AudioPrev`         | Previous track (targets active MPRIS player)     |
| `XF86AudioNext`         | Next track (targets active MPRIS player)         |
| `XF86AudioStop`         | Stop playback (targets active MPRIS player)      |
| `XF86MonBrightnessUp`   | Brightness +5% (repeating, works on lock screen) |
| `XF86MonBrightnessDown` | Brightness -5% (repeating, works on lock screen) |
| `XF86ScreenSaver`       | Lock screen                                      |

### Touchpad / Gesture

| Gesture                   | Action           |
| ------------------------- | ---------------- |
| 3-finger swipe horizontal | Switch workspace |

---

## Keyboard Layouts

- Two layouts: **US** (primary) and **Hebrew (il)**.
- Toggle: `Alt+Shift` and `Win+Space`.
- Per-window: each window remembers its own active layout; new windows default to US.
- Numlock on by default.

---

## Laptop Fn-key Remapping

The physical Fn row must be remapped so system tools and bindings work without per-app configuration:

| Physical Key | Required Function    |
| ------------ | -------------------- |
| F1           | Speaker mute         |
| F2           | Volume down          |
| F3           | Volume up            |
| F4           | Microphone mute      |
| F5           | Brightness down      |
| F6           | Brightness up        |
| F8           | Airplane mode toggle |
| F10          | Lock screen          |

---

## Touchpad

- Natural scroll enabled.
- Disable while typing enabled.
- No pointer acceleration.
- Right-click via bottom-right area (click-method: areas).
- Horizontal scrolling enabled.

---

## Audio

- PipeWire (modern audio server with PulseAudio compatibility).
- HDMI audio must be deprioritized — it should never be auto-selected as the default output.
- Bluetooth device should not act as an audio output for other devices (source-only roles).
- Media keys must always target the most recently active MPRIS player (not an arbitrary one).
- When a Bluetooth audio device connects, the default audio output must automatically switch to it; when it disconnects (and no other Bluetooth audio device remains), switch back to the built-in speakers.
- GUI volume mixer available (e.g., pavucontrol).

---

## Screen Capture

- **Screenshot**: region-select capture with immediate annotation/markup before saving.
- **Screen recorder**: full-session or region recording.
- Screenshots saved to `~/Pictures/Screenshots/`.

---

## Clipboard Management

- Persistent clipboard history accessible via `Super + V`.
- History of at least 1000 entries.
- Selecting an item from history pastes it immediately.
- Most recently used item moves to the top of the list.

---

## Notifications

- A notification daemon is required.
- Notifications must have small gaps between them and no visible frame/border.

---

## Display / Multi-Monitor Management

- A GUI tool to arrange monitor positions and resolutions.
- Automatic profile switching based on connected monitors (EDID fingerprinting).
- Named profiles for known setups (e.g., laptop-only, docked at home).
- DisplayLink (USB-C dock) support for additional external monitors.

---

## Theming

- Single theming source (Stylix) — no hardcoded colors anywhere.
- Dark polarity.
- Theme derived from a wallpaper image.
- Cursor: custom cursor theme, size 24.
- Fonts:
  - Monospace: JetBrainsMono Nerd Font
  - Serif: DejaVu Serif
  - Sans-serif: DejaVu Sans
  - Emoji: Noto Color Emoji
  - Size — applications: 12, desktop: 10, terminal: 15, popups: 15.
- Run `fc-cache -rf` after any font change.

---

## Terminal

- **Alacritty** as the primary terminal emulator.
- Font: JetBrainsMono Nerd Font, size 25.
- Cursor: block style.
- Dynamic window title.
- `TERMINAL=alacritty` environment variable set globally.
- Set as default for the `terminal` MIME type.

---

## Browsers

- **Chromium** as the default browser (set via `$BROWSER` and XDG MIME defaults).
- **Firefox** also installed as a fallback (captive portals, compatibility).
- Default for: `text/html`, `application/pdf`, `image/*`, `x-scheme-handler/http(s)`.

---

## Bluetooth

- Bluetooth enabled and powered on at boot.
- Experimental features enabled (required for newer iOS compatibility).
- GUI Bluetooth manager available.
- Noisy connect/disconnect notifications suppressed (iPhone tether auto-connects frequently).

---

## Networking

- NetworkManager with iwd Wi-Fi backend.
- FortiSSL VPN support.
- Network control accessible from bar and via a launcher-style dmenu interface.
- LocalSend for local-network file transfer.
- Predefined connections:
  - Wired ethernet (auto, high priority)
  - FortiSSL VPN (manual)
  - iPhone Wi-Fi hotspot (hidden SSID, auto)
  - iPhone Bluetooth tether (auto, lowest priority)
- Wi-Fi hotspot creation available.
- RDP/VNC client (Remmina) installed.

---

## Power Management (Laptop)

- CPU thermal management daemon.
- CPU frequency scaling: powersave on battery, performance on AC.
- Wi-Fi power saving enabled.
- Battery charge thresholds configurable (start charge at ~40%, stop at ~80%).

---

## Razer Hardware

- OpenRazer driver for Razer peripherals.
- GUI for RGB lighting control (Polychromatic).

---

## Social / Communication

- Discord
- Zoom
- Teams for Linux

---

## Entertainment

- Spotify (with ad blocking).
- Stremio (streaming; disable cache for smooth playback).
- Krita (digital painting).

---

## Office / Productivity

- LibreOffice suite with Hebrew CTL locale (automatic RTL direction detection).
- Obsidian (notes).
- Microsoft Office Online shortcuts (Word, PowerPoint via OneDrive).
- Hebrew fonts (Culmus + Vista fonts for Calibri/Cambria Hebrew rendering).
- Hebrew spell check (hunspell + he-il dictionary).
- Default app associations for .docx, .xlsx, .pptx, .odt, .ods, .odp, .doc, .xls, .ppt.

---

## Windows Compatibility

- Wine Staging + Winetricks for running Windows apps.
- PowerShell available (`pwsh`).

---

## System / Disk Utilities

- Disk partition GUI (GNOME Disks or equivalent).

---

## User Services

- **Per-window keyboard layout daemon** — must start with the graphical session, restart on failure.
- **doh1-autofill** — automated form filler, scheduled Fri/Sat at 17:00. Network-dependent, hardened (no extra capabilities, PrivateTmp, ProtectSystem).
- **Bluetooth power-on** — ensures Bluetooth adapter is powered on at boot.
- **AC caffeine** — suppresses idle-triggered sleep while on AC power; updates on plug/unplug events.

---

## CLI Environment

- Shell: **zsh**.
- Command-not-found: auto-installs missing programs via nix-shell (`NIX_AUTO_RUN=y`).
- Command correction (`thefuck` / `tf` / `f` aliases).
- Shell autocompletion framework (carapace).
- AI coding assistant CLI (`opencode`, aliased as `ai`).
- `xclip` for terminal clipboard integration.
- `just` for project task running.
- `stow` for dotfile management.
- `curl`, `wget` for HTTP from the terminal.
- `postman` for API testing.
- `btop` for resource monitoring.
