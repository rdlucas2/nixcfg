{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
    ../../modules/ssh.nix
    ../../modules/git.nix
    ../../modules/docker.nix
    ../../modules/dev-tools.nix
    ../../modules/niri/nixos.nix
    ../../modules/wifi.nix
  ];

  networking.hostName = "pi";
  nixpkgs.hostPlatform = "aarch64-linux";

  # Explicit, deliberate DHCP config: wired (end0) is a fallback that must
  # keep working, wireless (wlan0) is the primary link. Neither should be
  # left to the default useDHCP behavior by accident.
  networking.useDHCP = false;
  networking.interfaces.end0.useDHCP = true;
  networking.interfaces.wlan0.useDHCP = true;

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";

  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  environment.etc."niri/host.kdl".source = ./niri.kdl;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.ryan = import ../../home/ryan/home.nix;
}
