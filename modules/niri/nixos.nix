{ ... }:
{
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";

    # GTK 4.14+ defaults to its Vulkan renderer, but the Pi 4's V3D Vulkan
    # driver (v3dv) is incomplete: any GTK4 app segfaults inside
    # gdk_vulkan_context_begin_frame the first time a window repaints, which
    # looks like the app crashing on your first click. OpenGL on v3d is solid,
    # so pin the GL renderer. This is GPU-wide, not nautilus-specific — every
    # GTK4 app needs it.
    GSK_RENDERER = "gl";
  };

  programs.niri.enable = true;

  # Nautilus (installed in this module's home.nix) relies on gvfs for trash,
  # removable media, and network locations. Without it the file manager runs
  # but silently cannot do most of what a file manager is for.
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  # dconf backs GTK/GNOME settings persistence; GTK apps warn and lose state
  # without it.
  programs.dconf.enable = true;

  # A secret-service provider. VS Code and Brave both store their own logins
  # (VS Code's GitHub account, saved passwords) through libsecret, which needs
  # a daemon behind it. A full desktop environment supplies one; a bare niri
  # session does not, so without this VS Code's GitHub sign-in fails to
  # persist even once the git credential helper is working — they are separate
  # problems with separate fixes.
  #
  # The PAM entry unlocks the keyring with the login password so it is not a
  # second prompt every session. It touches the `login` stack only; sshd's PAM
  # stack is untouched, so SSH remains a working way in if this misbehaves.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
}
