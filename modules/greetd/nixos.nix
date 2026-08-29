{ pkgs, ... }:
{
  # Boot straight into the graphical session instead of a TTY login followed
  # by a manual `niri-session`.
  #
  # This deliberately does NOT use autologin. pam_gnome_keyring unlocks the
  # keyring with the password typed at login; with autologin no password is
  # ever typed, so the keyring would stay locked and VS Code's GitHub sign-in
  # and Brave's saved passwords would break again in exactly the way
  # modules/niri/nixos.nix and modules/dev-tools.nix set out to fix. Typing
  # the password once at a greeter is what makes the keyring work.
  #
  # Session environment survives the move off a TTY login shell:
  # environment.sessionVariables (BROWSER, GSK_RENDERER, NIXOS_OZONE_WL) are
  # written to /etc/pam/environment and read by pam_env.so, which sits in the
  # *session* phase of /etc/pam.d/login. The NixOS greetd module builds its
  # PAM stack as `session: include login`, so those variables are applied to
  # the greetd session too. That also means the gnome-keyring PAM rules
  # already enabled on the `login` service apply here without being declared
  # a second time.
  services.greetd = {
    enable = true;
    # Adjusts the systemd unit's TTY handling so boot messages do not scribble
    # over a terminal-based greeter.
    useTextGreeter = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      user = "greeter";
    };
  };

  # greetd takes over tty1 and the module disables autovt@tty1, so a broken
  # greeter means no console login. SSH is unaffected and remains the way back
  # in; deploy this with `test` first so a power cycle undoes it.
}
