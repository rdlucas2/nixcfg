{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  home.packages = with pkgs; [
    alacritty
    fuzzel
    nautilus
    wl-clipboard
    xwayland-satellite
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
}
