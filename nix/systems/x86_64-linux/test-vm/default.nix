{ namespace, lib, pkgs, config, inputs, ... }:

with lib;
with lib.${namespace};
{
  # Import qemu-vm.nix so virtualisation.* options (forwardPorts, sharedDirectories, etc.)
  # exist in this config. nixos-rebuild build-vm doesn't add it automatically for flakes.
  imports = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
    {
      # Extend every PAM service, including `other` (the fallback for new lock screens).
      options.security.pam.services = mkOption {
        type = types.attrsOf (types.submodule ({ ... }: {
          rules = {
            # Password-free authentication and credential setup for every VM user,
            # including root. Preserve the normal session stack (logind, etc.).
            auth = mkForce {
              test-vm = {
                order = 0;
                control = "required";
                modulePath = "${config.security.pam.package}/lib/security/pam_permit.so";
              };
            };
            account = mkForce {
              test-vm = {
                order = 0;
                control = "required";
                modulePath = "${config.security.pam.package}/lib/security/pam_permit.so";
              };
            };
          };
        }));
      };
    }
  ];

  ${namespace} = {
    networking.enable = mkForce false;
    apps = enabled;
    desktop.hyprland = enabled;
    desktop.displayManager.plasma = enabled;
  };

  # Share host /nix/store (nothing re-downloaded) and expose the dotfiles repo.
  # QEMU exposes the whole display (login screen and desktop) over local VNC.
  virtualisation = {
    mountHostNixStore = true;
    # virtiofsd needs shared guest memory to serve the host Nix store.
    qemu.enableSharedMemory = true;
    # Return guest free pages to the host without reducing the guest's RAM allowance.
    qemu.options = [
      "-device virtio-balloon-pci,free-page-reporting=on"
      "-vga virtio"
      "-display none"
      "-vnc 127.0.0.1:50"
      "-serial stdio"
      "-monitor none"
    ];
    graphics = true;
    # nixos-rebuild inside the guest evaluates this flake's full dependency graph, which
    # alone needs >1.7G resident; 2048M+swap still got OOM-killed under memory pressure.
    memorySize = 3584;
    cores = 2;
    # Default 1024M root disk is too small: nixos-rebuild inside the guest fetches/extracts
    # flake inputs not already in the host store, filling the disk and failing the build.
    diskSize = 8192;
    # The writable store overlay defaults to a RAM-backed tmpfs, which fills up (even with
    # plenty of disk free) once memorySize is exhausted. Back it by the disk image instead.
    writableStoreUseTmpfs = false;
  };

  # Reclaim file cache idle for 10s so free-page reporting can return it to the host.
  # Start below 50% free RAM, stop above 60%; leave anonymous application memory alone.
  boot.kernelParams = [
    # The kernel's default DAMON statistics monitor conflicts with reclamation.
    "damon_stat.enabled=N"
    "damon_reclaim.enabled=Y"
    "damon_reclaim.skip_anon=Y"
    "damon_reclaim.min_age=10000000"
    "damon_reclaim.min_nr_regions=100"
    "damon_reclaim.wmarks_high=600"
    "damon_reclaim.wmarks_mid=500"
    "damon_reclaim.wmarks_low=50"
    # Q35 splits RAM below/above 4 GiB; DAMON otherwise watches only the largest bank.
    "damon_reclaim.monitor_region_start=0"
    "damon_reclaim.monitor_region_end=${toString ((4096 + config.virtualisation.memorySize) * 1024 * 1024)}"
    # Report free blocks down to 128 KiB rather than only 2 MiB blocks.
    "page_reporting.page_reporting_order=5"
  ];

  # qemu-vm.nix forces swapDevices = [] via mkVMOverride (priority 10). A nix build/eval
  # inside the guest can exceed the 2048M memorySize and get OOM-killed; outrank it with a
  # swapfile on the (disk-backed) root so builds spill to disk instead of dying.
  swapDevices = lib.mkOverride 5 [
    { device = "/swapfile"; size = 2048; }
  ];

  virtualisation = {
    forwardPorts = [
      { from = "host"; host.address = "127.0.0.1"; host.port = 2222; guest.port = 22; }
      { from = "host"; host.address = "127.0.0.1"; host.port = 8081; guest.port = 8081; }
      { from = "host"; host.address = "127.0.0.1"; host.port = 8082; guest.port = 8082; }
    ];
    sharedDirectories = {
      dotfiles = {
        source = "/home/roey/.dotfiles";
        target = "/dotfiles";
      };
    };
  };

  networking.hostName = "test-vm";
  networking.firewall.enable = mkForce false;
  services.fail2ban.enable = mkForce false;
  networking.firewall.allowedTCPPorts = [ 22 8081 8082 ];

  # Registration runs before nix-daemon; Lix must access the store directly.
  systemd.services.register-nix-paths.environment.NIX_REMOTE = "local";

  users.users.roey.initialPassword = "test";
  users.users.roey.extraGroups = [ "video" "seat" ];
  users.users.root.initialPassword = "root";
  security.sudo.wheelNeedsPassword = false;
  security.sudo.extraRules = [{
    users = [ "ALL" ];
    runAs = "ALL:ALL";
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) { return polkit.Result.YES; });
  '';

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
    settings.PasswordAuthentication = true;
    settings.PermitEmptyPasswords = true;
  };

  # Allow the host user's SSH key to log in as root without a password prompt.
  # Public key is safe to commit. keyFiles doesn't work in pure flake evaluation.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+ObfW9r+0OIzMZcHFQ8xZT1fBXrGxs7i5BCnnzJii/ roey@laptop"
  ];

  services.seatd.enable = true;

  # Use Mesa's software renderer with the virtual GPU; no host GPU is required.
  environment.sessionVariables.LIBGL_ALWAYS_SOFTWARE = "1";
  systemd.services.plasmalogin.environment.LIBGL_ALWAYS_SOFTWARE = "1";
  systemd.user.services.plasma-login-kwin_wayland.environment.LIBGL_ALWAYS_SOFTWARE = "1";
  services.displayManager.autoLogin.enable = mkForce false;

  systemd.tmpfiles.rules = [
    # The greeter ignores `defaultSession` and falls back to the first session
    # alphabetically (plain hyprland.desktop), which skips UWSM and therefore
    # graphical-session.target (wayle, idle, screensaver...). Pre-select the UWSM
    # session on every boot, like a previous login on the laptop would.
    "d /var/lib/plasmalogin 0750 plasmalogin plasmalogin -"
    "d /var/lib/plasmalogin/.local 0700 plasmalogin plasmalogin -"
    "d /var/lib/plasmalogin/.local/state 0700 plasmalogin plasmalogin -"
    "f+ /var/lib/plasmalogin/.local/state/plasma-login-greeterstaterc 0600 plasmalogin plasmalogin - [General]\\nLastLoggedInSession=hyprland-uwsm.desktop\\nLastLoggedInUser=roey\\n"
    "d /run/user/1000 0700 roey users -"
    # Keep the user's MCP services available before and after desktop login.
    "f /var/lib/systemd/linger/roey 0644 root root -"
  ];

  # Hypruse is stdio-only; mcp-proxy serves it over HTTP without bypassing
  # its session discovery, input cleanup, or other startup hooks.
  systemd.services.hypruse-mcp = {
    description = "Hypruse MCP for the test VM desktop";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "display-manager.service" ];
    path = [ pkgs.uv pkgs.hyprland pkgs.grim pkgs.wtype pkgs.imagemagick pkgs.systemd ];
    environment = {
      HOME = "/home/roey";
      XDG_RUNTIME_DIR = "/run/user/1000";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
      HYPRUSE_SCREENSHOT_MODE = "image";
      PYTHONPATH = "";
    };
    serviceConfig = {
      User = "roey";
      WorkingDirectory = "/dotfiles";
      ExecStart = "${pkgs.mcp-proxy}/bin/mcp-proxy --host 0.0.0.0 --port 8081 --pass-environment -- ${pkgs.uv}/bin/uvx hypruse==0.11.0";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  systemd.services.nixos-mcp = {
    description = "NixOS MCP for the test VM";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ config.nix.package pkgs.git ];
    environment = {
      HOME = "/home/roey";
      MCP_NIXOS_TRANSPORT = "http";
      MCP_NIXOS_HOST = "0.0.0.0";
      MCP_NIXOS_PORT = "8082";
    };
    serviceConfig = {
      User = "roey";
      WorkingDirectory = "/dotfiles";
      ExecStart = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  environment.systemPackages = [ pkgs.git ];

  system.stateVersion = "24.11";
}
