{ pkgs, ... }:

{
  "google".metaData.alias =
    "@g"; # builtin engines only support specifying one additional alias

  "MyNixos" = {
    urls = [{
      template = "https://mynixos.com/search";
      iconurl = "https://mynixos.com/favicon.ico";
      params = [{
        name = "q";
        value = "{searchTerms}";
      }];
    }];
    definedAliases = [ "@mn" "@myn" "@mynos" "@mynixos" ];
  };

  "Nix Packages" = {
    urls = [{
      template = "https://search.nixos.org/packages";
      params = [
        {
          name = "type";
          value = "packages";
        }
        {
          name = "query";
          value = "{searchTerms}";
        }
      ];
    }];
    icon =
      "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    definedAliases = [ "@np" "@nixpkgs" ];
  };

  "Source Graph" = {
    urls = [{
      template = "https://sourcegraph.com/search";
      iconUpdateURL = "https://sourcegraph.com/favicon.ico";
      params = [{
        name = "q";
        value = "{searchTerms}";
      }];
    }];
    definedAliases = [ "@sg" "@sourcegraph" ];
  };

  "ecosia" = {
    urls = [{
      template = "https://www.ecosia.org/search";
      iconurl = "https://www.ecosia.org/search/favicon.ico";
      params = [
        {
          name = "method";
          value = "index";
        }
        {
          name = "q";
          value = "{searchTerms}";
        }
      ];
    }];
    definedAliases = [ "@es" "@ecosia" ];
  };

  "Github" = {
    urls = [{
      template = "https://github.com/search";
      iconurl = "https://github.com/favicon.ico";
      params = [
        {
          name = "type";
          value = "repositories";
        }
        {
          name = "q";
          value = "{searchTerms}";
        }
      ];
    }];
    definedAliases = [ "@gh" "@github" ];
  };

}
