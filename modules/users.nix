{ config, pkgs, ... }:
{
  sops.secrets.ryan-password = {
    neededForUsers = true;
  };

  # root cannot be removed by a config change (unlike a declaratively-created
  # normal user, which NixOS deletes if it disappears from the config), so
  # giving root a password here is a rescue path that cannot repeat the
  # "fallback account silently deleted" failure that stranded us before.
  sops.secrets.root-password.neededForUsers = true;
  users.users.root.hashedPasswordFile = config.sops.secrets.root-password.path;

  users.users.ryan = {
    isNormalUser = true;
    # Pin explicitly: /home/ryan on the Pi is already owned by uid 1001;
    # letting this float to the default (1000) would orphan the home dir.
    uid = 1001;
    extraGroups = [ "wheel" "docker" ];
    hashedPasswordFile = config.sops.secrets.ryan-password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINwHPtJgpAZFAkDEJzOZ5IHDiUiw5FifT6P40V4is2Nv ryan@wsl-nixcfg"
    ];
  };
}
