{ pkgs, ... }:

# Software brightness for monitors with no real backlight control.
# DisplayLink-connected monitors don't support DDC/CI (verified: the I2C
# bus exists but ddcutil reports "cannot be used for DDC/CI communication"
# — a driver limitation, not a permissions issue) and don't respond to
# Hyprland's CTM/gamma control either (evdi's capture path sits outside
# that pipeline). The only thing that visibly works is a real rendered
# surface, since that *is* captured into the DisplayLink framebuffer: a
# persistent, click-through, semi-transparent black wlr-layer-shell overlay
# per targeted output, with alpha driven by a brightness percentage.
#
# Run as `monitor-dim --skip <output-name>...` — every other connected
# output gets dimmed. Control it over its Unix socket at
# $XDG_RUNTIME_DIR/monitor-dim.sock with newline-free commands:
#   set <0-100>   absolute brightness percent
#   up <n>        relative increase
#   down <n>      relative decrease
# 100 = no dim (fully transparent overlay), 0 = maximum dim (never fully
# opaque — capped so the monitor doesn't go completely black).
pkgs.rustPlatform.buildRustPackage {
  pname = "monitor-dim";
  version = "0.1.0";
  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.libxkbcommon pkgs.wayland ];

  meta.mainProgram = "monitor-dim";
}
