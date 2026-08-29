{ ... }:
{
  # BROWSER is set at the NixOS level rather than in this module's home.nix
  # on purpose. home-manager's `home.sessionVariables` reaches systemd user
  # services (via ~/.config/environment.d) but not a plain TTY login shell
  # unless home-manager also manages the shell rc files, which it does not
  # here. niri is started from a TTY login shell and every GUI app inherits
  # that environment, so a home-manager-only definition would leave BROWSER
  # unset for exactly the terminals `claude` and `gh auth login` run in.
  #
  # environment.sessionVariables lands in /etc/set-environment, which login
  # shells source — the same mechanism GSK_RENDERER in modules/niri/nixos.nix
  # already relies on.
  #
  # The value is a bare command name, resolved on PATH, because brave is
  # installed into the user profile by this module's home.nix rather than
  # system-wide.
  environment.sessionVariables.BROWSER = "brave";

  # Bookmarks are delivered as a Chromium enterprise policy rather than by
  # writing into Brave's profile. The profile's Bookmarks file is rewritten by
  # the browser at runtime, so anything declarative placed there is racy and
  # gets clobbered; a policy file is read-only input the browser never fights
  # over. /etc/brave/policies is the policy directory compiled into the Brave
  # binary — confirmed by grepping the installed binary rather than assumed
  # from Chromium's own path.
  #
  # They are encrypted because this repo is public and the set includes the
  # home network's internal service map, a Tailscale address and a private
  # chat link. sops-nix decrypts to the path below at activation, and
  # sops-install-secrets creates the parent directories itself.
  #
  # Trade-off worth knowing: ManagedBookmarks renders as a read-only folder on
  # the bookmarks bar. Editing happens here, via `sops secrets/bookmarks.yaml`,
  # not in the browser.
  sops.secrets.brave-bookmarks = {
    sopsFile = ../../secrets/bookmarks.yaml;
    path = "/etc/brave/policies/managed/bookmarks.json";
    mode = "0444";
  };
}
