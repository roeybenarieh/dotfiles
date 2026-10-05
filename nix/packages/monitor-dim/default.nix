{ pkgs, ... }:

# Software brightness for monitors with no real backlight control.
# DisplayLink-connected monitors don't support DDC/CI (verified: the I2C
# bus exists but ddcutil reports "cannot be used for DDC/CI communication"
# — a driver limitation, not a permissions issue) and don't respond to
# Hyprland's CTM/gamma control either (evdi's capture path sits outside
# that pipeline). A Hyprland final-frame shader modifies the actual rendered
# pixels, including overlay popups and the software cursor, before scanout.
# It owns decoration:screen_shader while running; --skip uses wl_output IDs.
#
# Run as `monitor-dim --skip <output-name>...` — every other connected
# output gets dimmed. Control it over its Unix socket at
# $XDG_RUNTIME_DIR/monitor-dim.sock with newline-free commands:
#   set <0-100>   absolute brightness percent
#   up <n>        relative increase
#   down <n>      relative decrease
# 100 = no dim, 0 = fully black.
pkgs.rustPlatform.buildRustPackage {
  pname = "monitor-dim";
  version = "0.2.0";
  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta.mainProgram = "monitor-dim";
}
