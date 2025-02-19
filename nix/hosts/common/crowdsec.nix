# crowd security -  security tool designed to protect servers by monitoring users+network activities
# for flake documenation: https://codeberg.org/kampka/nix-flake-crowdsec
# web interface: https://app.crowdsec.net/security-engines
{ inputs, pkgs, ... }:

{
  nixpkgs.overlays = [ inputs.crowdsec.overlays.default ];

  # systemd.services.crowdsec.serviceConfig = {
  #   ExecStartPre =
  #     let
  #       script = pkgs.writeScriptBin "register-bouncer" ''
  #         #!${pkgs.runtimeShell}
  #         set -eu
  #         set -o pipefail
  #
  #         if ! cscli bouncers list | grep -q "my-bouncer"; then
  #           cscli bouncers add "my-bouncer" --key "<api-key>"
  #         fi
  #       '';
  #     in
  #     [ "${script}/bin/register-bouncer" ];
  # };

  services = {
    crowdsec =
      let
        yaml = (pkgs.formats.yaml { }).generate;
        acquisitions_file = yaml "acquisitions.yaml" {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        };
      in
      {
        enable = true;
        # enrollKeyFile = "/path/to/enroll-key";

        allowLocalJournalAccess = true;
        # according to https://docs.crowdsec.net/docs/configuration/crowdsec_configuration
        settings = {
          crowdsec_service.acquisition_path = acquisitions_file;
          # api.server = {
          #   listen_uri = "127.0.0.1:8080";
          # };
          prometheus = {
            enabled = true;
            level = "full";
            listen_addr = "0.0.0.0";
            listen_port = 6060;
          };
        };
      };
    crowdsec-firewall-bouncer = {
      enable = false;
      settings = {
        # api_key = "<api-key>";
        api_url = "http://localhost:8081";
      };
    };
  };
}
