{ pkgs, ... }:

# Hyprlock music widget. Reads MPRIS players over D-Bus (no playerctl) and keeps
# the lock-screen cache current. Runtime tools (curl, ImageMagick) and the
# Stylix-derived settings are wrapped in by the screensaver module.
pkgs.rustPlatform.buildRustPackage {
  pname = "hyprlock-music";
  version = "0.1.0";
  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.dbus ];

  meta.mainProgram = "hyprlock-music";
}
