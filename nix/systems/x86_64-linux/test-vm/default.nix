{ namespace, lib, pkgs, config, inputs, ... }:

with lib;
with lib.${namespace};
{
  # Import qemu-vm.nix so virtualisation.* options (forwardPorts, sharedDirectories, etc.)
  # exist in this config. nixos-rebuild build-vm doesn't add it automatically for flakes.
  imports = [ "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];

  ${namespace} = {
    networking.enable = mkForce false;
    apps = enabled;
    desktop.hyprland = enabled;
    desktop.sddm = disabled;
  };

  # Share host /nix/store (nothing re-downloaded) and expose the dotfiles repo.
  # Port forwards: 5950 → wayvnc, 2222 → SSH.
  virtualisation = {
    mountHostNixStore = true;
    graphics = false;
    memorySize = 2048;
    cores = 2;
    forwardPorts = [
      { from = "host"; host.port = 5950; guest.port = 5950; }
      { from = "host"; host.port = 2222; guest.port = 22; }
    ];
    sharedDirectories = {
      dotfiles = {
        source = "/home/roey/.dotfiles";
        target = "/dotfiles";
        securityModel = "none";
      };
    };
  };

  networking.hostName = "test-vm";
  networking.firewall.allowedTCPPorts = [ 5950 22 ];

  users.users.roey.initialPassword = "test";
  users.users.roey.extraGroups = [ "video" "seat" ];
  users.users.root.initialPassword = "root";
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
    settings.PasswordAuthentication = true;
  };

  # Allow the host user's SSH key to log in as root without a password prompt.
  # Public key is safe to commit. keyFiles doesn't work in pure flake evaluation.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+ObfW9r+0OIzMZcHFQ8xZT1fBXrGxs7i5BCnnzJii/ roey@laptop"
  ];

  services.seatd.enable = true;

  systemd.tmpfiles.rules = [
    "d /run/user/1000 0700 roey users -"
    # Enable linger so logind never tears down /run/user/1000 while Hyprland runs
    "f /var/lib/systemd/linger/roey 0644 root root -"
  ];

  # Headless Hyprland: no DRM/GPU needed; wayvnc captures the virtual display.
  systemd.services.hyprland-test = {
    description = "Hyprland compositor (headless, captured by wayvnc)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" "systemd-tmpfiles-setup.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    environment = {
      WLR_LIBINPUT_NO_DEVICES = "1";
      WLR_BACKENDS = "headless";
      WLR_RENDERER = "pixman";
      LIBSEAT_BACKEND = "noop";
      XDG_RUNTIME_DIR = "/run/user/1000";
      HOME = "/home/roey";
      XDG_CONFIG_HOME = "/home/roey/.config";
      XDG_DATA_HOME = "/home/roey/.local/share";
      XDG_STATE_HOME = "/home/roey/.local/state";
      XDG_CURRENT_DESKTOP = "Hyprland";
    };
    serviceConfig = {
      User = "roey";
      Group = "users";
      ExecStart = "${pkgs.hyprland}/bin/Hyprland";
      # After Hyprland starts, wait for its Wayland socket then export
      # WAYLAND_DISPLAY + HYPRLAND_INSTANCE_SIGNATURE into roey's user
      # systemd so HM user services (wayle, etc.) can connect.
      ExecStartPost = pkgs.writeShellScript "hyprland-import-env" ''
        for i in $(seq 1 30); do
          SOCK=$(ls /run/user/1000/wayland-* 2>/dev/null | grep -v lock | head -1)
          # Find the active Hyprland instance by looking for .socket.sock (only present on live instance)
          SIG=$(for d in /run/user/1000/hypr/*/; do [ -S "''${d}.socket.sock" ] && basename "$d" && break; done)
          if [ -n "$SOCK" ] && [ -n "$SIG" ]; then
            DISPLAY_NAME=$(basename "$SOCK")
            ${pkgs.systemd}/bin/systemctl --user -M roey@ set-environment \
              WAYLAND_DISPLAY="$DISPLAY_NAME" \
              HYPRLAND_INSTANCE_SIGNATURE="$SIG" \
              XDG_RUNTIME_DIR=/run/user/1000 \
              XDG_CURRENT_DESKTOP=Hyprland \
              HOME=/home/roey
            ${pkgs.systemd}/bin/systemctl --user -M roey@ start --no-block nixos-fake-graphical-session.target
            exit 0
          fi
          sleep 1
        done
        echo "WARNING: Hyprland socket never appeared"
        exit 0
      '';
      Restart = "on-failure";
      RestartSec = "3s";
      StandardError = "append:/tmp/hyprland-stderr.log";
    };
  };

  systemd.services.wayvnc-test = {
    description = "VNC server for headless Hyprland";
    wantedBy = [ "multi-user.target" ];
    after = [ "hyprland-test.service" ];
    unitConfig.BindsTo = [ "hyprland-test.service" ];
    environment = {
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
    serviceConfig = {
      User = "roey";
      Group = "users";
      ExecStart = pkgs.writeShellScript "start-wayvnc" ''
        for i in $(seq 1 60); do
          SOCK=$(ls /run/user/1000/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1)
          if [ -n "$SOCK" ]; then
            DISPLAY_NAME=$(basename "$SOCK")
            echo "Connecting wayvnc to $DISPLAY_NAME"
            exec env WAYLAND_DISPLAY="$DISPLAY_NAME" \
              ${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5950
          fi
          sleep 1
        done
        echo "ERROR: Hyprland socket not found after 60 s"
        exit 1
      '';
      Restart = "always";
      RestartSec = "5s";
    };
  };

  environment.systemPackages = [ pkgs.git ];

  system.stateVersion = "24.11";
}
