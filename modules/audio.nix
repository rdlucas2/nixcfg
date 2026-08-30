{ ... }:
{
  # PipeWire is already switched on transitively — enabling niri pulls in
  # NixOS's graphical-desktop module, which enables it as a side effect. That
  # works, but it means the audio stack on this machine is an accident of
  # another choice rather than a decision. Declaring it here makes it
  # deliberate and keeps it working if the graphical session is ever
  # reconfigured or removed.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true; # the ALSA/Pulse shims most applications still expect

    # NO HDMI preference is set here, and that is deliberate.
    #
    # An earlier version of this module raised the HDMI sink's priority so
    # sound would follow the display. That turned out to be actively harmful.
    # The XREAL One glasses reach this host through a Peakdo HDMI-to-USB-C
    # converter, and that converter passes the audio EDID without carrying the
    # audio stream: the Pi reads the glasses by name, advertises FL/FR LPCM at
    # 48 kHz, and clocks samples out at exactly real time — while nothing comes
    # out of the glasses at all.
    #
    # Confirmed on unrelated hardware: the same converter and glasses on an
    # x86 desktop enumerate an "XREAL One" audio device that is equally silent,
    # and the glasses produce sound when plugged straight into a phone's USB-C.
    # The fault is the converter, not this machine.
    #
    # So preferring HDMI routes audio into a sink that cannot produce sound.
    # Leaving priorities alone lets the analogue output — which is verified
    # working, via direct ALSA playback to card 0 — remain the fallback, and
    # lets Bluetooth headphones take over when connected, which WirePlumber
    # does on its own.
  };
}
