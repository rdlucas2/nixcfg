{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  home.packages = with pkgs; [
    alacritty
    # niri has no wallpaper of its own — `background` is not a valid config
    # node — so the desktop background comes from a layer-shell client.
    # swaybg is the minimal one: a small C program that paints a background
    # surface and then sits idle, which is what a Pi 4 wants.
    swaybg
    fuzzel
    nautilus
    wl-clipboard
    xwayland-satellite
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
}
