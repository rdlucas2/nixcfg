{ pkgs, ... }:
let
  # Connect every paired, trusted device that advertises an Audio Sink.
  # Deliberately not keyed on a MAC address: this works for any headphones
  # paired later, and carries over to another host unchanged.
  autoconnect = pkgs.writeShellScript "bluetooth-autoconnect" ''
    set -u
    bluetoothctl=${pkgs.bluez}/bin/bluetoothctl

    # Headphones are not always ready the instant the session starts, so retry
    # a few times with a widening gap rather than giving up on the first miss.
    for delay in 0 2 4 8; do
      [ "$delay" -gt 0 ] && sleep "$delay"

      remaining=0
      for mac in $($bluetoothctl devices Paired | awk '{print $2}'); do
        info=$($bluetoothctl info "$mac" 2>/dev/null) || continue

        # Only audio sinks, only trusted ones, and skip anything already up.
        case "$info" in *"Audio Sink"*) ;; *) continue ;; esac
        case "$info" in *"Trusted: yes"*) ;; *) continue ;; esac
        case "$info" in *"Connected: yes"*) continue ;; esac

        echo "connecting $mac"
        $bluetoothctl connect "$mac" >/dev/null 2>&1 || remaining=1
      done

      [ "$remaining" -eq 0 ] && exit 0
    done
    exit 0
  '';
in
{
  # The Pi 4's BCM43455 provides Bluetooth alongside WiFi; the controller and
  # its firmware were already working at the kernel level (hci0 present,
  # BCM4345C0.hcd patched, not rfkill-blocked). Only bluez was missing, because
  # nothing in this config ever enabled it.
  hardware.bluetooth = {
    enable = true;

    # Bring the adapter up at boot rather than leaving it to be powered on by
    # hand after every reboot. Headphones are useless if the radio is off.
    powerOnBoot = true;

    settings.General = {
      # Reports headphone battery level through the standard interface, which
      # bluetoothctl and desktop applets can then display.
      Experimental = true;
    };
  };

  # PipeWire handles A2DP itself — WirePlumber ships the Bluetooth session
  # support and will expose a paired pair of headphones as an ordinary sink, so
  # no extra audio configuration is needed here.
  #
  # Pairing is done with `bluetoothctl`, installed by hardware.bluetooth.enable.
  # It is deliberately not scripted: pairing writes keys to /var/lib/bluetooth,
  # which is device state, not configuration, and survives rebuilds.
  #
  # `trust` alone does not bring headphones back after a logout. It only tells
  # bluez to accept connections the device initiates; bluez never dials out on
  # its own, and the [Policy] section it writes contains nothing but
  # AutoEnable, which merely powers the adapter on at boot. Headphones normally
  # re-establish the link themselves when switched on — but a pair left powered
  # while the link drops sits idle, with neither end reaching out.
  #
  # So the session asks. graphical-session.target is pulled in by niri.service,
  # and lingering is off for this user, so the user manager stops at logout and
  # starts again at login — which makes this fire once per session, exactly
  # when it is wanted.
  systemd.user.services.bluetooth-autoconnect = {
    description = "Connect trusted Bluetooth audio devices at session start";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = autoconnect;
    };
  };

  # Worth knowing on this hardware: the BCM43455 shares one 2.4 GHz antenna
  # between WiFi and Bluetooth, and A2DP is notorious for stuttering when both
  # are busy on that band. This host associates on 5 GHz (channel 157), which
  # keeps the two apart — so if audio ever starts breaking up, check that WiFi
  # has not fallen back to a 2.4 GHz channel before blaming the headphones.
}
