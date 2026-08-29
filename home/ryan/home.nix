{ ... }:
{
  imports = [ ../../modules/niri/home.nix ];

  home.stateVersion = "25.11";
  home.username = "ryan";
  home.homeDirectory = "/home/ryan";

  programs.git = {
    enable = true;
    userName = "Ryan Lucas";
    userEmail = "rdlucas2@gmail.com";
  };
}
