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
}
