{ config, pkgs, ... }:
{
  # This module exists because `nixos-rebuild switch` activates a whole new
  # system closure, replacing the previous one entirely. Anything that
  # provided networking in the old generation but isn't declared here is
  # simply gone the moment the new generation activates. WiFi was omitted
  # from an earlier config, and a Pi deployed over WiFi lost its only link
  # mid-deploy as a result. Wireless networking MUST be declared, or it will
  # be destroyed out from under any device that depends on it.

  # NixOS runs wpa_supplicant as an unprivileged `wpa_supplicant` user, not as
  # root, so the default sops mode (0400 root:root) is unreadable to it and the
  # daemon fails auth with "EXT PW FILE: could not open file ... Permission
  # denied" while still happily finding the SSID. Hand the secret to that user.
  sops.secrets.wifi-env = {
    owner = "wpa_supplicant";
    mode = "0400";
  };

  # Without a country code the radio sits in the "world" domain (country 00),
  # where nearly every channel is PASSIVE-SCAN: the card may listen but may not
  # transmit. Association attempts then time out silently, which reads like a
  # bad password but is actually a regulatory block. The 5 GHz band the AP uses
  # (ch 157 / 5785 MHz) is not permitted at all under country 00.
  # wirelessRegulatoryDatabase installs wireless-regdb, without which the
  # country setting has no rules to apply.
  hardware.wirelessRegulatoryDatabase = true;
  networking.wireless.extraConfig = ''
    country=US
  '';

  networking.wireless.enable = true;
  networking.wireless.secretsFile = config.sops.secrets.wifi-env.path;

  networking.wireless.networks."THE_INTERNET" = {
    pskRaw = "ext:wifi_psk";
    # The AP advertises "PSK SAE" — WPA2/WPA3 transition mode — so it signals
    # management-frame protection. ieee80211w=1 negotiates PMF when offered and
    # stays compatible when it is not; leaving it off can make such APs ignore
    # the client outright, which also surfaces as an auth timeout.
    extraConfig = ''
      ieee80211w=1
    '';
  };

  # Ship the wireless CLI tools. Without these there is no way to scan for
  # APs or inspect association state on a headless box, which turns any WiFi
  # problem into guesswork.
  environment.systemPackages = [
    pkgs.iw
    pkgs.wpa_supplicant # provides wpa_cli
  ];
}
