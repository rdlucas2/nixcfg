{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
    ../../modules/ssh.nix
    ../../modules/git.nix
    ../../modules/docker.nix
  ];

  networking.hostName = "pi";
  nixpkgs.hostPlatform = "aarch64-linux";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";

  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.ryan = import ../../home/ryan/home.nix;
}
