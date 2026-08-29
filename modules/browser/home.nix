{ pkgs, ... }:
{
  # Brave is MPL-2.0 in nixpkgs (meta.license.free = true) and has a prebuilt
  # aarch64 binary in cache.nixos.org, so it needs no allowUnfreePredicate
  # entry and does not build from source on the Pi.
  #
  # Brave is Chromium, so it has the identical credential-backend detection
  # problem VS Code does (see modules/dev-tools.nix): an unrecognised
  # XDG_CURRENT_DESKTOP makes Electron fall back to its near-plaintext
  # `basic` password store instead of the running gnome-keyring. Brave fails
  # quietly rather than prompting, so this would otherwise go unnoticed.
  home.packages = [
    (pkgs.brave.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })
  ];

  # Two separate mechanisms decide what "open this link" means, and both have
  # to be set or the CLI logins that prompted this stay broken:
  #
  #   BROWSER      — consulted first by terminal programs. `claude` and
  #                  `gh auth login` both need to hand a sign-in URL to a
  #                  browser; with nothing set they have nothing to launch.
  #                  Set in this module's nixos.nix, not here — see the note
  #                  there for why home-manager is the wrong level for it.
  #   mimeapps     — what xdg-open (and therefore GUI apps opening links)
  #                  consults. A bare niri session has no desktop environment
  #                  supplying a default, so without this clicking a link in
  #                  VS Code or nautilus does nothing at all.

  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        # From nixpkgs' brave derivation: fileStem = "brave-browser" is the
        # basename of the installed .desktop file. It is deliberately not the
        # same as the executable name ("brave") or the app-id
        # ("com.brave.Browser"), so this cannot be guessed from either.
        brave = "brave-browser.desktop";
      in
      {
        "text/html" = brave;
        "x-scheme-handler/http" = brave;
        "x-scheme-handler/https" = brave;
        "x-scheme-handler/about" = brave;
        "x-scheme-handler/unknown" = brave;
      };
  };
}
