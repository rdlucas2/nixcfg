# nixcfg Phase 1: Repo Foundation + Raspberry Pi Design

## Purpose

Rebuild `rdlucas2/nixcfg` as a flake-based, multi-host NixOS configuration,
starting with a single host: a Raspberry Pi 4 (8GB) already running NixOS,
used as a safe environment to learn Nix and do small coding tasks. This is
**Phase 1** of a two-phase plan. Phase 2 — replacing a Windows gaming PC
with a NixOS desktop (Steam, Discord, TeamSpeak, Epic/GOG game portals,
full desktop environment) — is out of scope here and will get its own
brainstorm/spec once Phase 1 is proven out.

Inspiration and prior art: `NathanielWroblewski/nixcfg` (simple,
low-ceremony structure: `constants/`, `pkgcfg/`, `pkgsets/`, `hosts/`) and
`BJSummerfield/nixcfg` (more mature: `modules/<name>/{nixos.nix,home.nix}`
split, `mine.*` option namespace, sops-nix, disko, CI checks, a documented
host-provisioning runbook). This design takes Nathaniel's structural
simplicity and BJ's clean per-concern module boundaries, without BJ's
custom options framework — with two hosts (Pi now, gaming PC later), a
toggle-abstraction layer is premature; hosts just import the plain module
files they want.

## Success criteria

- `nixcfg` is a working flake with one host, `pi`, corresponding to the
  Raspberry Pi already running at `192.168.0.71`.
- The Pi's *existing* install is adopted (its real disk UUID and boot
  mechanism reused) — not reflashed or reinstalled.
- `sudo nixos-rebuild switch --flake .#pi` succeeds on the Pi and survives
  a reboot.
- After switching: SSH key auth still works, `git`/`gh`/`claude`/`docker`
  are usable from a terminal, and running `niri-session` from the console
  brings up a working desktop (terminal, launcher, file manager) on the
  external monitor.
- One real secret (the `ryan` user's password hash) is managed through
  sops-nix, proving the pattern end-to-end.

## Existing hardware/system facts (verified 2026-08-28)

These are load-bearing for the plan and were confirmed by SSHing into the
running Pi — not assumptions:

- **Model:** Raspberry Pi 4 Model B Rev 1.4, 8GB RAM, aarch64, mounted in
  a pi-top enclosure (built-in screen + USB keyboard), plus an external
  monitor and Xreal AR glasses (used as a plain external display for now
  — no head-tracking/AR-specific driver work in Phase 1).
- **Storage:** one 238GB SD card (`/dev/mmcblk1`): `mmcblk1p1` (30M,
  firmware/boot area) + `mmcblk1p2` (238G, ext4 root, mounted at `/`).
- **OS:** NixOS 25.11 "Xantusia", kernel 6.12.74. Currently
  **channel-based** — `nix-channel --list` is empty and no `flake.nix`
  exists anywhere on the system; `/etc/nixos/configuration.nix` is the
  untouched installer-generated template (nothing customized yet).
- **Boot:** U-Boot + `boot.loader.generic-extlinux-compatible`, boot
  files under `/boot/extlinux` and `/boot/nixos`. No separate
  `/boot/firmware` partition — this is the modern mainline U-Boot +
  extlinux path, not the legacy Raspberry Pi firmware/config.txt path.
- **Graphics:** `vc4`/`v3d` kernel modules already loaded (mainline KMS,
  auto-detected — no extra firmware wiring needed).
- **WiFi:** `brcmfmac` already loaded and connected, IP `192.168.0.71/24`
  on `wlan0`. WiFi credentials were configured outside of Nix (e.g. by
  the imaging tool) and stay that way in Phase 1 — bringing WiFi under
  declarative Nix + sops is a cheap future addition, not required now.
- **Root filesystem UUID** is the fixed placeholder
  `44444444-4444-4444-8888-888888888888` — standard for NixOS sd-images,
  where the UUID is baked in at image-build time and every card flashed
  from that image shares it. This confirms adoption-in-place is safe:
  the flake's `hardware-configuration.nix` can reference this exact UUID.
- **Access:** passwordless SSH key auth from the WSL dev machine to
  `nixos@192.168.0.71` is already working (ed25519 key generated on the
  dev machine, installed via `ssh-copy-id`).
- **Not yet present on the Pi:** `git`, Nix flakes support
  (`experimental-features` unset in `/etc/nix/nix.conf`).
- **Dev machine:** the repo lives in WSL2 Ubuntu 24.04
  (`/home/ryan/_git/nixcfg`), which has no local Nix installation yet.
  GitHub remote already configured: `github.com/rdlucas2/nixcfg.git`.

## Repo layout

```
nixcfg/
├── flake.nix
├── flake.lock
├── .sops.yaml
├── secrets/
│   └── secrets.yaml
├── hosts/
│   └── pi/
│       ├── default.nix
│       ├── hardware-configuration.nix
│       └── niri.kdl
├── modules/
│   ├── users.nix
│   ├── git.nix
│   ├── ssh.nix
│   ├── docker.nix
│   ├── dev-tools.nix
│   └── niri/
│       ├── nixos.nix
│       ├── home.nix
│       └── config.kdl
└── home/
    └── ryan/
        └── home.nix
```

**Module convention:** each file under `modules/` is a plain NixOS or
home-manager module — no custom `mine.*`/`options.*` declarations, no
per-module enable flags. A host opts into a module by importing the file
directly in its `default.nix`. This is intentionally simpler than
BJ's options-namespace pattern; revisit only if/when a third or fourth
host makes an on/off toggle abstraction actually pay for itself.

## flake.nix

- `inputs`: `nixpkgs` (`nixos-unstable`, matching the Pi's current
  25.11/unstable-derived install), `home-manager` (`inputs.nixpkgs.follows
  = "nixpkgs"`), `sops-nix` (`inputs.nixpkgs.follows = "nixpkgs"`).
- `outputs`: a `forAllSystems`-style helper is unnecessary for one host;
  `nixosConfigurations.pi` is defined directly for `aarch64-linux`,
  wiring in `home-manager.nixosModules.home-manager` and
  `sops-nix.nixosModules.sops`, with `specialArgs = { inherit inputs; }`.

## hosts/pi/default.nix

Imports, in order:
1. `./hardware-configuration.nix`
2. `../../modules/users.nix`
3. `../../modules/git.nix`
4. `../../modules/ssh.nix`
5. `../../modules/docker.nix`
6. `../../modules/dev-tools.nix`
7. `../../modules/niri/nixos.nix`

Plus host-specific settings: `networking.hostName = "pi";`,
`nixpkgs.hostPlatform = "aarch64-linux";`,
`boot.loader.generic-extlinux-compatible.enable = true;`,
`boot.loader.grub.enable = false;`, `system.stateVersion = "25.11";`,
`home-manager.users.ryan = import ../../home/ryan/home.nix;`,
`sops.defaultSopsFile = ../../secrets/secrets.yaml;`.

`sops.age.sshKeyPaths` is left at its sops-nix default
(`/etc/ssh/ssh_host_ed25519_key`), so decryption uses the **host's own**
SSH host key — not the dev machine's per-user age key. This matters
because `ryan-password` backs `hashedPasswordFile`, which sops-nix must
decrypt during system activation as root, before any user session
exists to hold a per-user key; the secret is declared with
`sops.secrets.ryan-password.neededForUsers = true;` in `modules/users.nix`
so activation orders it correctly. The Pi's host age key (derived from
its existing SSH host key via `ssh-to-age`) is registered in
`.sops.yaml` as the recipient for this reason — see the Secrets section.

## hosts/pi/hardware-configuration.nix

Copied verbatim from the Pi's own `/etc/nixos/hardware-configuration.nix`
(already fetched and reproduced below for the record):

```nix
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };
  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
```

## modules/users.nix

Defines `sops.secrets.ryan-password.neededForUsers = true;` and
`users.users.ryan`: `isNormalUser = true`,
`extraGroups = [ "wheel" "docker" ]`, `shell = pkgs.bash` (or a shell
module later — not in scope now), `hashedPasswordFile =
config.sops.secrets.ryan-password.path`, and an `openssh.authorizedKeys.keys`
entry containing the dev machine's public key (`~/.ssh/id_ed25519.pub`,
already generated) so key auth survives the switch to the new config.

## modules/git.nix

System-level: `environment.systemPackages = [ pkgs.git ];`. This module
is imported by the host; the home-manager `programs.git` settings
(`userName = "Ryan Lucas"`, `userEmail = "rdlucas2@gmail.com"`) live in
`home/ryan/home.nix` directly rather than a separate home.nix file, since
it's a few lines and doesn't need its own home/nixos split like niri
does.

## modules/ssh.nix

`services.openssh = { enable = true; settings = { PasswordAuthentication
= false; PermitRootLogin = "no"; }; };` — tightens the current
(functionally default) config now that key auth is confirmed working.

## modules/docker.nix

`virtualisation.docker.enable = true;`

## modules/dev-tools.nix

- `environment.systemPackages` includes `gh` and `claude-code` (nixpkgs
  package name to be confirmed at implementation time; if unpackaged,
  falls back to a Node.js + `npm install -g @anthropic-ai/claude-code`
  wrapper derivation).
- VS Code Remote-SSH fix: `programs.nix-ld.enable = true;` — the
  simplest fix for NixOS's non-FHS layout breaking VS Code's
  auto-downloaded server component, avoiding a dependency on an
  external `vscode-server` flake input. (VS Code itself runs on the
  Windows/WSL side and connects via Remote-SSH; it is not installed on
  the Pi.)

## modules/niri/{nixos.nix,home.nix,config.kdl}

- `nixos.nix`: `programs.niri.enable = true;`,
  `environment.sessionVariables.NIXOS_OZONE_WL = "1";`. No greetd/display
  manager — niri is launched on demand by running `niri-session` from a
  console login, matching "would be nice to bring up a graphical
  interface" rather than "always-on desktop."
- `home.nix`: installs `alacritty`, `fuzzel`, `nautilus`,
  `wl-clipboard`, `xwayland-satellite`; enables `xdg.portal` with the
  gtk portal backend; writes `xdg.configFile."niri/config.kdl".source =
  ./config.kdl;` directly (no `extraConfig`/`extraBinds` options, no
  `dynamic.kdl`/`binds.kdl` indirection — per your explicit instruction
  to skip that part of BJ's design, since it only pays off once
  multiple modules need to contribute config fragments, which doesn't
  apply yet).
- `config.kdl`: adapted from BJ's `modules/niri/config.kdl` — same
  keybindings (column/window focus and movement, workspace switching,
  screenshot binds, volume/brightness keys), same layout/gaps/cursor
  settings. Dropped: the `mine.user._1password.silentStart` line (no
  1Password in this repo) and the `include optional=true
  "~/.config/niri/dynamic.kdl"` / `binds.kdl` / `tests.kdl` lines at the
  bottom (the dynamic-config mechanism being skipped). The
  `include optional=true "/etc/niri/host.kdl"` line is kept, backed by
  `hosts/pi/niri.kdl`, so host-specific output/window rules (e.g. Xreal
  glasses display mode, once known) have somewhere to live without
  touching the shared config.

## home/ryan/home.nix

Home-manager entrypoint for the `ryan` user. Imports
`../../modules/niri/home.nix`. Sets `home.stateVersion = "25.11";`,
`home.username = "ryan";`, `home.homeDirectory = "/home/ryan";`, and
`programs.git = { enable = true; userName = "Ryan Lucas"; userEmail =
"rdlucas2@gmail.com"; };`.

## Secrets (sops-nix)

- An age keypair is generated on the WSL dev machine
  (`~/.config/sops/age/keys.txt` via `age-keygen`), and its public key
  is registered as a recipient in `.sops.yaml`.
- `.sops.yaml` defines one creation rule matching `secrets/secrets.yaml`,
  with the dev machine's age key (and, once generated during
  implementation, the Pi's own host age key derived from its SSH host
  key — needed so the Pi can decrypt the secret at boot/activation
  without the dev machine's key being present on it) as recipients.
- `secrets/secrets.yaml` (encrypted) contains one key: `ryan-password`,
  a value produced by `mkpasswd -m sha-512` for a real password.
- Explicitly out of scope for Phase 1: WiFi PSK (WiFi stays managed
  outside Nix), GitHub/Claude auth tokens (handled by `gh auth login`
  and Claude Code's own login flow, not nix-managed secrets), and the
  dev machine's SSH keypair (already generated locally, not stored in
  the repo).

## Bootstrap sequence (adopting the running Pi, not reinstalling)

This is the one-time path to get from "existing channel-based install"
to "flake-managed" without reflashing:

1. On the WSL dev machine: install Nix (Determinate Systems installer or
   the official script), enabling flakes.
2. On the WSL dev machine: `age-keygen` a keypair, register it in
   `.sops.yaml`, create `secrets/secrets.yaml` with the `ryan-password`
   entry.
3. Build out the repo structure above, commit, push to
   `github.com/rdlucas2/nixcfg`.
4. Over the existing SSH session to the Pi: bootstrap `git` (e.g.
   `nix-shell -p git --run '...'` or `nix-env -iA nixpkgs.git`) and
   enable flakes by appending `experimental-features = nix-command
   flakes` to `/etc/nix/nix.conf`.
5. Clone the repo onto the Pi, derive the Pi's age identity from its SSH
   host key (`ssh-to-age`), add it to `.sops.yaml` as a recipient,
   `sops updatekeys secrets/secrets.yaml`, commit and push from the dev
   machine, pull on the Pi.
6. `sudo nixos-rebuild switch --flake .#pi` run locally on the Pi (not
   cross-built from WSL — an 8GB Pi 4 building its own closure is simple
   and avoids needing a remote builder or cross-compilation setup).
7. Reboot, then verify against the success criteria above.

## Testing/verification plan

- `nix flake check` from the WSL machine catches evaluation errors
  before touching the Pi.
- `nixos-rebuild dry-build --flake .#pi` (run on the Pi, or from WSL
  with `--target-host`) confirms the configuration builds without
  switching anything.
- `nixos-rebuild switch --flake .#pi`, then reboot, then manually
  verify: SSH key auth still works; `git`, `gh`, `claude`, `docker` are
  on `PATH` and functional (`docker run hello-world`); `niri-session`
  from the console brings up niri on the external monitor with working
  alacritty, fuzzel, and nautilus; `sops` correctly decrypted
  `ryan-password` (login as `ryan` works with the real password, not
  locked out).

## Explicitly out of scope for Phase 1

- Steam, Discord, TeamSpeak, Epic Games, GOG — all Phase 2 (gaming PC).
- Any desktop auto-login / display manager — niri stays on-demand.
- Xreal AR glasses head-tracking / AR-specific software — treated as a
  plain external monitor only.
- Stylix or any visual theming.
- Declarative WiFi management.
- A `mine.*`-style custom options framework — revisit only once host
  count justifies it.
