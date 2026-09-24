{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  home.packages = with pkgs; [
    alacritty
    # niri has no wallpaper of its own — `background` is not a valid config
    # node — so the desktop background comes from a layer-shell client.
    # swaybg is the minimal one: a small C program that paints a background
    # surface and then sits idle, which is what a Pi 4 wants.
    swaybg
    fuzzel
    nautilus
    wl-clipboard
    xwayland-satellite
    # Game streaming client for the gaming PC over Tailscale. Not Steam Link:
    # Valve never ships an aarch64 build (Flathub's is x86_64-only, and the
    # Raspberry Pi Foundation's old .deb doesn't fit a NixOS system). Moonlight
    # is the actively maintained aarch64 client and speaks the same
    # GameStream-derived protocol; it needs Sunshine running on the gaming PC
    # as the host (NVIDIA's own GameStream server was discontinued in 2023, so
    # this applies regardless of GPU vendor).
    #
    # Vulkan is force-disabled for this binary specifically. moonlight-qt
    # prefers its libplacebo/Vulkan renderer when a Vulkan driver is present,
    # and the Pi 4's Broadcom driver (V3DV) is present but its swapchain
    # support is broken: streaming connected fine, but the picture froze
    # solid while input kept working — confirmed in the app's own log as
    # repeated `vkCreateSwapchainKHR(...): VK_ERROR_OUT_OF_HOST_MEMORY`.
    # Hiding the Vulkan ICD from just this binary makes it fall back to the
    # EGL renderer, which works correctly on this GPU. Scoped to moonlight
    # rather than set session-wide so it doesn't affect Vulkan use by other
    # apps (e.g. Brave's GPU rendering).
    (moonlight-qt.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
      postFixup = (oldAttrs.postFixup or "") + ''
        wrapProgram $out/bin/moonlight --set VK_ICD_FILENAMES /dev/null
      '';
    }))
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
}
