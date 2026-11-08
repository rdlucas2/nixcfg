{ config, pkgs, ... }:
{
  # This module exists because `nixos-rebuild switch` activates a whole new
  # system closure, replacing the previous one entirely. Anything that
  # provided networking in the old generation but isn't declared here is
  # simply gone the moment the new generation activates. WiFi was omitted
  # from an earlier config, and a Pi deployed over WiFi lost its only link
  # mid-deploy as a result. Wireless networking MUST be declared, or it will
  # be destroyed out from under any device that depends on it.
  #
  # NetworkManager (rather than bare declarative wpa_supplicant) so networks
  # can be discovered and joined at runtime — e.g. a smart plug's setup AP —
  # with `nmtui` / `nmcli`, while the home network stays declared below via
  # ensureProfiles so a rebuild can never strand the Pi.

  # ensureProfiles is applied by a root-run oneshot (NetworkManager-ensure-
  # profiles), so the sops default of 0400 root:root is what it needs. (The
  # old `owner = "wpa_supplicant"` was only for the unprivileged supplicant
  # reading the secret directly, which NM no longer does.)
  # The file must contain a line `wifi_psk=<psk>` — same as before.
  sops.secrets.wifi-env = {
    mode = "0400";
  };

  # Without a country code the radio sits in the "world" domain (country 00),
  # where nearly every channel is PASSIVE-SCAN: the card may listen but may not
  # transmit. Association attempts then time out silently, which reads like a
  # bad password but is actually a regulatory block. The 5 GHz band the AP uses
  # (ch 157 / 5785 MHz) is not permitted at all under country 00.
  # wirelessRegulatoryDatabase installs wireless-regdb, without which the
  # country setting has no rules to apply. NM's supplicant has no `country=`
  # line, so the domain is set on cfg80211 itself at module load.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
  '';

  # NM runs its own wpa_supplicant; the declarative one must be off or the two
  # fight over wlan0.
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.secrets.wifi-env.path ];
    profiles.THE_INTERNET = {
      connection = {
        id = "THE_INTERNET";
        type = "wifi";
        interface-name = "wlan0";
        autoconnect = true;
        # Prefer home over any ad-hoc network joined later.
        autoconnect-priority = 100;
      };
      wifi = {
        mode = "infrastructure";
        ssid = "THE_INTERNET";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "$wifi_psk";
        # The AP advertises "PSK SAE" — WPA2/WPA3 transition mode — so it
        # signals management-frame protection. pmf=2 ("optional") is NM's
        # equivalent of wpa_supplicant's ieee80211w=1: negotiate PMF when
        # offered, stay compatible when not. Leaving it off can make such APs
        # ignore the client outright, which surfaces as an auth timeout.
        pmf = 2;
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  # iw for low-level radio inspection; nmcli/nmtui ship with NetworkManager.
  # Without these there is no way to scan for APs or inspect association state
  # on a headless box, which turns any WiFi problem into guesswork.
  environment.systemPackages = [
    pkgs.iw
  ];
}
