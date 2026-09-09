{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.keyboard-layout-indicator;
  notifySend = getExe pkgs.libnotify;

  cppSrc = pkgs.writeText "hyprland-layout-notify.cpp" ''
    #include <chrono>
    #include <cstdlib>
    #include <cstring>
    #include <glob.h>
    #include <string>
    #include <sys/socket.h>
    #include <sys/un.h>
    #include <sys/wait.h>
    #include <unistd.h>

    // How long after a focus change to suppress layout notifications.
    // The per-window-layout daemon reacts within a few ms; 300 ms is a
    // safe margin that won't swallow real manual keypresses.
    static constexpr double FOCUS_SUPPRESS_WINDOW = 0.3;

    static std::string get_socket_path() {
        const char* xdg = getenv("XDG_RUNTIME_DIR");
        std::string runtime_dir =
            xdg ? xdg : ("/run/user/" + std::to_string(getuid()));

        const char* hypr_sig = getenv("HYPRLAND_INSTANCE_SIGNATURE");
        if (hypr_sig && *hypr_sig) {
            std::string path =
                runtime_dir + "/hypr/" + hypr_sig + "/.socket2.sock";
            if (access(path.c_str(), F_OK) == 0)
                return path;
        }

        std::string pattern = runtime_dir + "/hypr/*/.socket2.sock";
        glob_t g{};
        if (glob(pattern.c_str(), 0, nullptr, &g) == 0 && g.gl_pathc > 0) {
            std::string result = g.gl_pathv[0];
            globfree(&g);
            return result;
        }
        globfree(&g);
        return "";
    }

    static void send_notification(const std::string& layout) {
        pid_t pid = fork();
        if (pid == 0) {
            execl("${notifySend}", "${notifySend}",
                  "-a", "Hyprland",
                  "-r", "9991",
                  "-t", "1200",
                  "-i", "input-keyboard",
                  "Keyboard Layout",
                  layout.c_str(),
                  static_cast<char*>(nullptr));
            _exit(1);
        }
        if (pid > 0) {
            int status;
            waitpid(pid, &status, 0);
        }
    }

    int main() {
        while (true) {
            std::string sock_path = get_socket_path();
            if (sock_path.empty()) { sleep(1); continue; }

            int fd = socket(AF_UNIX, SOCK_STREAM, 0);
            if (fd < 0) { sleep(1); continue; }

            sockaddr_un addr{};
            addr.sun_family = AF_UNIX;
            strncpy(addr.sun_path, sock_path.c_str(),
                    sizeof(addr.sun_path) - 1);

            if (connect(fd, reinterpret_cast<sockaddr*>(&addr),
                        sizeof(addr)) < 0) {
                close(fd);
                sleep(1);
                continue;
            }

            std::string last_layout;
            auto last_focus_change = std::chrono::steady_clock::now();
            std::string buffer;
            char buf[4096];

            while (true) {
                ssize_t n = recv(fd, buf, sizeof(buf), 0);
                if (n <= 0) break;
                buffer.append(buf, static_cast<size_t>(n));
                size_t pos;
                while ((pos = buffer.find('\n')) != std::string::npos) {
                    std::string line = buffer.substr(0, pos);
                    buffer.erase(0, pos + 1);
                    if (line.compare(0, 14, "activewindow>>") == 0) {
                        last_focus_change = std::chrono::steady_clock::now();
                    } else if (line.compare(0, 14, "activelayout>>") == 0) {
                        auto comma = line.find(',', 14);
                        if (comma != std::string::npos) {
                            std::string layout = line.substr(comma + 1);
                            auto s = layout.find_first_not_of(' ');
                            auto e = layout.find_last_not_of(' ');
                            if (s != std::string::npos)
                                layout = layout.substr(s, e - s + 1);
                            if (layout != last_layout) {
                                last_layout = layout;
                                auto elapsed = std::chrono::duration<double>(
                                    std::chrono::steady_clock::now() -
                                    last_focus_change).count();
                                if (elapsed > FOCUS_SUPPRESS_WINDOW)
                                    send_notification(layout);
                            }
                        }
                    }
                }
            }

            close(fd);
            sleep(1);
        }
    }
  '';

  layoutNotifyBin = pkgs.stdenv.mkDerivation {
    name = "hyprland-layout-notify";
    src = cppSrc;
    dontUnpack = true;
    buildPhase = ''
      g++ -std=c++17 -O2 $src -o hyprland-layout-notify
    '';
    installPhase = ''
      install -Dm755 hyprland-layout-notify $out/bin/hyprland-layout-notify
    '';
  };
in
{
  options.${namespace}.desktop.hyprland.keyboard-layout-indicator = with types; {
    enable = mkBoolOpt false "Whether to enable the Hyprland keyboard layout change notification indicator.";
  };

  config = mkIf cfg.enable {
    systemd.user.services.hyprland-keyboard-layout-notify = {
      Unit = {
        Description = "Keyboard layout change notification indicator for Hyprland";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${layoutNotifyBin}/bin/hyprland-layout-notify";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
