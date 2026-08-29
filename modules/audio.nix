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

    # Route audio out of HDMI in preference to the Pi's analogue jack.
    #
    # Both sinks ship with priority.session = 1000, and that tie is why sound
    # was coming out of the pi-top's speakers rather than the display: with
    # nothing to separate them WirePlumber picked the analogue fallback.
    # Raising the HDMI sink breaks the tie in favour of the display.
    #
    # This is a preference, not a pin. When no HDMI display is attached the
    # sink does not exist, so WirePlumber falls back to the analogue output on
    # its own — no rule needed for that direction.
    #
    # The node name encodes the HDMI controller's address, so it identifies the
    # port rather than what is plugged into it. The Pi 4's second port would be
    # a separate node (platform-fef05700) and is not matched here, since
    # nothing uses it.
    #
    # Caveat worth knowing: the glasses and the AOC monitor share this one
    # port, so this rule cannot tell them apart. If the monitor turns out to
    # expose an HDMI audio sink despite having no speakers, it would win this
    # preference and play to nothing. A speakerless display usually advertises
    # no audio in its EDID and so creates no sink at all, in which case the
    # fallback handles it — but that is untested, because only one display can
    # be connected at a time.
    wireplumber.extraConfig."51-prefer-hdmi-output" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "alsa_output.platform-fef00700.hdmi.hdmi-stereo"; } ];
          actions.update-props = {
            "priority.session" = 2000;
            "priority.driver" = 2000;
          };
        }
      ];
    };
  };
}
