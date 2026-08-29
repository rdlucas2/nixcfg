{ pkgs, lib, ... }:
{
  # Allow exactly the unfree packages this module needs, by name — not a
  # blanket `allowUnfree`, which would silently permit anything unfree that
  # any other module later pulls in.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "vscode"
    ];

  environment.systemPackages = [
    pkgs.gh
    pkgs.claude-code
    # Microsoft ships aarch64 builds, so this runs natively on the Pi. It is
    # Electron, so expect it to be heavier than the terminal tooling here.
    pkgs.vscode
    # Terminal editor: single Rust binary, LSP and tree-sitter built in, no
    # plugin manager or config file needed to be useful. Cached for aarch64.
    pkgs.helix
  ];

  # VS Code's Remote-SSH server downloads prebuilt binaries that expect a
  # standard FHS layout, which NixOS does not have. nix-ld provides the
  # dynamic loader they look for, so connecting to this host from VS Code on
  # another machine works as well as running VS Code locally.
  programs.nix-ld.enable = true;
}
