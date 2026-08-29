{ pkgs, lib, ... }:
{
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];

  environment.systemPackages = [
    pkgs.gh
    pkgs.claude-code
  ];

  programs.nix-ld.enable = true;
}
