{ config, pkgs, ... }:
{
  # This module exists because `nixos-rebuild switch` activates a whole new
  # system closure, replacing the previous one entirely. Anything that
  # provided networking in the old generation but isn't declared here is
  # simply gone the moment the new generation activates. WiFi was omitted
  # from an earlier config, and a Pi deployed over WiFi lost its only link
  # mid-deploy as a result. Wireless networking MUST be declared, or it will
  # be destroyed out from under any device that depends on it.

  sops.secrets.wifi-env = { };

  networking.wireless.enable = true;
  networking.wireless.secretsFile = config.sops.secrets.wifi-env.path;
  networking.wireless.networks."THE_INTERNET".pskRaw = "ext:wifi_psk";
}
