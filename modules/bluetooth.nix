{ ... }:
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
  # Worth knowing on this hardware: the BCM43455 shares one 2.4 GHz antenna
  # between WiFi and Bluetooth, and A2DP is notorious for stuttering when both
  # are busy on that band. This host associates on 5 GHz (channel 157), which
  # keeps the two apart — so if audio ever starts breaking up, check that WiFi
  # has not fallen back to a 2.4 GHz channel before blaming the headphones.
}
