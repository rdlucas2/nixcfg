{ pkgs, ... }:
{
  imports = [
    ../../modules/niri/home.nix
    ../../modules/browser/home.nix
  ];

  home.stateVersion = "25.11";
  home.username = "ryan";
  home.homeDirectory = "/home/ryan";

  programs.git = {
    enable = true;

    # `settings` is the current home-manager API. The older `userName`,
    # `userEmail` and `extraConfig` options still work but emit deprecation
    # warnings on every evaluation.
    settings = {
      user.name = "Ryan Lucas";
      user.email = "rdlucas2@gmail.com";

      # The remote is HTTPS and no credential helper was configured, so every
      # push fell back to asking for a password — which GitHub stopped
      # accepting in 2021. That is what VS Code's git integration was hitting.
      # `gh` is already installed and already the thing holding a GitHub
      # token, so let it answer git's credential requests rather than storing
      # a second copy of the token somewhere. Scoped to github.com so other
      # hosts are unaffected.
      credential."https://github.com".helper =
        "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };
}
