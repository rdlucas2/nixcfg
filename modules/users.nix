{ config, pkgs, ... }:
{
  sops.secrets.ryan-password = {
    neededForUsers = true;
  };

  users.users.ryan = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    hashedPasswordFile = config.sops.secrets.ryan-password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINwHPtJgpAZFAkDEJzOZ5IHDiUiw5FifT6P40V4is2Nv ryan@wsl-nixcfg"
    ];
  };
}
