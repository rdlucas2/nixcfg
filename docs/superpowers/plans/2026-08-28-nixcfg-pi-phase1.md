# nixcfg Phase 1: Repo Foundation + Raspberry Pi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `rdlucas2/nixcfg` into a flake-based NixOS configuration and adopt the already-running Raspberry Pi 4 into it, ending with a working dev/test box (git, gh, docker, claude-code, VS Code Remote-SSH support, an on-demand niri desktop) and one real secret managed through sops-nix.

**Architecture:** One flake, one host (`pi`). Plain per-concern NixOS/home-manager modules under `modules/`, imported directly by `hosts/pi/default.nix` — no custom options framework. The Pi's existing install (fixed-UUID root partition, U-Boot + `generic-extlinux-compatible` boot) is adopted in place via `nixos-rebuild switch`, not reflashed.

**Tech Stack:** Nix flakes, NixOS 25.11 (nixos-unstable), home-manager, sops-nix, niri (Wayland compositor).

**Spec:** `docs/superpowers/specs/2026-08-28-nixcfg-pi-phase1-design.md`

## Global Constraints

- Adopt the Pi's existing install in place — do not reflash or reinstall. Reuse its real root filesystem UUID `44444444-4444-4444-8888-888888888888`.
- No custom `mine.*`/options-framework layer. Modules under `modules/` are plain NixOS/home-manager modules; hosts import the files they want directly.
- `system.stateVersion` and `home.stateVersion` are `"25.11"` (matches the Pi's installed NixOS release).
- niri's `config.kdl` is static and written directly — no `extraConfig`/`extraBinds` options, no `dynamic.kdl`/`binds.kdl` indirection (BJ's pattern for that is intentionally skipped per the spec).
- No display manager or auto-login for niri — it launches on demand via `niri-session` from the console.
- No stylix theming, no declarative WiFi management, no 1Password integration, no Steam/Discord/TeamSpeak/game-portal work — all out of scope for Phase 1.
- Secrets scope for Phase 1 is exactly one value: `ryan-password` via sops-nix. GitHub and Claude Code auth stay interactive (`gh auth login`, Claude Code's own login flow) — not nix-managed secrets.
- git identity: `userName = "Ryan Lucas"`, `userEmail = "rdlucas2@gmail.com"`.
- Primary user is `ryan`. The pre-existing `nixos` account is left alone and will survive the switch to the new config, because `users.mutableUsers` defaults to `true` in NixOS (undeclared users aren't deleted) — this is the safety net for the very first deploy.
- The dev machine's SSH public key, already installed on the Pi (as the `nixos` user) and to be carried over to the `ryan` user, is exactly: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINwHPtJgpAZFAkDEJzOZ5IHDiUiw5FifT6P40V4is2Nv ryan@wsl-nixcfg`
- GitHub remote is `https://github.com/rdlucas2/nixcfg.git`. Pi's current reachable address is `192.168.0.71`.

---

## Task 1: Bootstrap Nix on the dev machine

**Files:** none (host tooling only)

**Interfaces:**
- Produces: a working `nix` CLI with flakes enabled, used by every later task's `nix eval`/`nix flake` commands.

- [ ] **Step 1: Install Nix via the Determinate Systems installer**

Run on the WSL dev machine:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
```

This installer enables flake support (`nix-command` and `flakes`) by default, so no manual `nix.conf` edit is needed on this machine.

- [ ] **Step 2: Open a new shell and verify**

Run:

```bash
exec bash -l
nix --version
nix flake --help >/dev/null && echo "flakes OK"
```

Expected: a version string (e.g. `nix (Nix) 2.24.x`) and `flakes OK` printed with no "experimental feature" error.

- [ ] **Step 3: Commit**

Nothing to commit — this step only installs local tooling on the dev machine.

---

## Task 2: Generate the sops age keypair and create `.sops.yaml`

**Files:**
- Create: `.sops.yaml`

**Interfaces:**
- Consumes: `nix` from Task 1.
- Produces: `~/.config/sops/age/keys.txt` on the dev machine (the age identity used to decrypt secrets locally); `.sops.yaml` with the dev key registered — later extended in Task 12 with the Pi's own host key.

- [ ] **Step 1: Generate the age keypair**

```bash
mkdir -p ~/.config/sops/age
nix shell nixpkgs#age --command age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

Expected output includes a line like:

```
Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Copy that `age1...` value — it's needed in the next step.

- [ ] **Step 2: Write `.sops.yaml`**

Create `/home/ryan/_git/nixcfg/.sops.yaml`, substituting the real public key from Step 1 in place of `<DEV_AGE_PUBKEY>`:

```yaml
keys:
  - &dev_ryan <DEV_AGE_PUBKEY>
creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *dev_ryan
```

- [ ] **Step 3: Verify the key is readable**

```bash
grep 'public key' ~/.config/sops/age/keys.txt
```

Expected: prints the same `age1...` value used in `.sops.yaml`.

- [ ] **Step 4: Commit**

```bash
git add .sops.yaml
git commit -m "sops: register dev machine age key"
```

---

## Task 3: Create and encrypt `secrets/secrets.yaml`

**Files:**
- Create: `secrets/secrets.yaml` (committed encrypted)

**Interfaces:**
- Consumes: `.sops.yaml` from Task 2.
- Produces: the `ryan-password` secret, consumed by `modules/users.nix` in Task 5 via `config.sops.secrets.ryan-password.path`.

- [ ] **Step 1: Ask the user for the real password**

Ask: "What password do you want set for the `ryan` account on the Pi?" Do not choose one yourself — this is a real login credential. Use their answer in place of `<PASSWORD>` below.

- [ ] **Step 2: Hash the password and write the plaintext file**

```bash
mkdir -p secrets
cat > secrets/secrets.yaml <<EOF
ryan-password: $(openssl passwd -6 '<PASSWORD>')
EOF
```

- [ ] **Step 3: Encrypt it in place**

```bash
nix shell nixpkgs#sops --command sops --encrypt --in-place secrets/secrets.yaml
```

- [ ] **Step 4: Verify it decrypts correctly**

```bash
nix shell nixpkgs#sops --command sops --decrypt secrets/secrets.yaml
```

Expected: prints `ryan-password: $6$...` (the same hash produced in Step 2), and the on-disk file itself is now encrypted (confirm with `cat secrets/secrets.yaml` — it should show `ENC[AES256_GCM,...]`, not the plaintext hash).

- [ ] **Step 5: Commit**

```bash
git add secrets/secrets.yaml
git commit -m "secrets: add encrypted ryan-password"
```

---

## Task 4: Scaffold the flake (walking skeleton)

**Files:**
- Create: `flake.nix`
- Create: `hosts/pi/hardware-configuration.nix`
- Create: `hosts/pi/default.nix`
- Create: `home/ryan/home.nix`

**Interfaces:**
- Consumes: `secrets/secrets.yaml` path from Task 3 (referenced by `sops.defaultSopsFile`).
- Produces: `nixosConfigurations.pi`, evaluable end-to-end with zero optional modules yet — the base every later task's module gets imported into. `home/ryan/home.nix` is a bare skeleton other tasks extend.

- [ ] **Step 1: Write `hosts/pi/hardware-configuration.nix`**

Copied verbatim from the Pi's own `/etc/nixos/hardware-configuration.nix` (already confirmed by SSHing into the running Pi):

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
```

- [ ] **Step 2: Write `home/ryan/home.nix` (skeleton)**

```nix
{ ... }:
{
  home.stateVersion = "25.11";
  home.username = "ryan";
  home.homeDirectory = "/home/ryan";
}
```

- [ ] **Step 3: Write `hosts/pi/default.nix`**

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "pi";
  nixpkgs.hostPlatform = "aarch64-linux";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";

  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.ryan = import ../../home/ryan/home.nix;
}
```

- [ ] **Step 4: Write `flake.nix`**

```nix
{
  description = "rdlucas2 nixcfg";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
    {
      nixosConfigurations.pi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          ./hosts/pi
        ];
      };
    };
}
```

- [ ] **Step 5: Lock and evaluate**

```bash
cd /home/ryan/_git/nixcfg
git add flake.nix hosts/pi home/ryan
nix flake lock
nix eval .#nixosConfigurations.pi.config.system.build.toplevel.drvPath
```

Expected: `nix flake lock` creates `flake.lock` with no errors; the `nix eval` prints a single `/nix/store/...-nixos-system-pi-25.11....drv` path string (proof the whole configuration — hardware, sops, home-manager, boot loader — evaluates cleanly end to end), not an error.

- [ ] **Step 6: Commit**

```bash
git add flake.nix flake.lock hosts/pi home/ryan
git commit -m "flake: scaffold pi host (walking skeleton)"
```

---

## Task 5: `modules/users.nix` — define `ryan`, wire the password secret

**Files:**
- Create: `modules/users.nix`
- Modify: `hosts/pi/default.nix` (add import)

**Interfaces:**
- Consumes: `ryan-password` secret from Task 3; the dev machine's public key (Global Constraints).
- Produces: `users.users.ryan`, consumed operationally by Task 11/13 (SSH target switches from `nixos@` to `ryan@` after first deploy).

- [ ] **Step 1: Write `modules/users.nix`**

```nix
{ config, pkgs, ... }:
{
  sops.secrets.ryan-password = {
    neededForUsers = true;
  };

  users.users.ryan = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    hashedPasswordFile = config.sops.secrets.ryan-password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINwHPtJgpAZFAkDEJzOZ5IHDiUiw5FifT6P40V4is2Nv ryan@wsl-nixcfg"
    ];
  };
}
```

- [ ] **Step 2: Wire the import into `hosts/pi/default.nix`**

```nix
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
  ];
```

- [ ] **Step 3: Verify**

```bash
nix eval .#nixosConfigurations.pi.config.users.users.ryan.isNormalUser
nix eval .#nixosConfigurations.pi.config.sops.secrets.ryan-password.neededForUsers
nix eval .#nixosConfigurations.pi.config.system.build.toplevel.drvPath
```

Expected: `true`, `true`, and a `.drv` path with no errors.

- [ ] **Step 4: Commit**

```bash
git add modules/users.nix hosts/pi/default.nix
git commit -m "modules: add ryan user with sops-backed password"
```

---

## Task 6: `modules/ssh.nix` — harden sshd

**Files:**
- Create: `modules/ssh.nix`
- Modify: `hosts/pi/default.nix` (add import)

**Interfaces:**
- Consumes: nothing new.
- Produces: `services.openssh.*`, no later task depends on this directly.

- [ ] **Step 1: Write `modules/ssh.nix`**

```nix
{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
```

- [ ] **Step 2: Wire the import**

```nix
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
    ../../modules/ssh.nix
  ];
```

- [ ] **Step 3: Verify**

```bash
nix eval .#nixosConfigurations.pi.config.services.openssh.settings.PasswordAuthentication
nix eval .#nixosConfigurations.pi.config.system.build.toplevel.drvPath
```

Expected: `false`, and a `.drv` path with no errors.

- [ ] **Step 4: Commit**

```bash
git add modules/ssh.nix hosts/pi/default.nix
git commit -m "modules: harden sshd (key-only auth)"
```

---

## Task 7: `modules/git.nix` + home-manager git config

**Files:**
- Create: `modules/git.nix`
- Modify: `hosts/pi/default.nix` (add import)
- Modify: `home/ryan/home.nix` (add `programs.git`)

**Interfaces:**
- Consumes: git identity from Global Constraints.
- Produces: `git` on `PATH`, `programs.git` home-manager config.

- [ ] **Step 1: Write `modules/git.nix`**

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.git ];
}
```

- [ ] **Step 2: Wire the import**

```nix
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
    ../../modules/ssh.nix
    ../../modules/git.nix
  ];
```

- [ ] **Step 3: Extend `home/ryan/home.nix`**

```nix
{ ... }:
{
  home.stateVersion = "25.11";
  home.username = "ryan";
  home.homeDirectory = "/home/ryan";

  programs.git = {
    enable = true;
    userName = "Ryan Lucas";
    userEmail = "rdlucas2@gmail.com";
  };
}
```

- [ ] **Step 4: Verify**

```bash
nix eval .#nixosConfigurations.pi.config.home-manager.users.ryan.programs.git.userEmail
nix eval .#nixosConfigurations.pi.config.system.build.toplevel.drvPath
```

Expected: `"rdlucas2@gmail.com"`, and a `.drv` path with no errors.

- [ ] **Step 5: Commit**

```bash
git add modules/git.nix hosts/pi/default.nix home/ryan/home.nix
git commit -m "modules: add git, configure identity via home-manager"
```

---

## Task 8: `modules/docker.nix`

**Files:**
- Create: `modules/docker.nix`
- Modify: `hosts/pi/default.nix` (add import)

**Interfaces:**
- Consumes: `ryan` already in the `docker` group (Task 5).
- Produces: `virtualisation.docker.enable`, verified end-to-end in Task 13.

- [ ] **Step 1: Write `modules/docker.nix`**

```nix
{ ... }:
{
  virtualisation.docker.enable = true;
}
```

- [ ] **Step 2: Wire the import**

```nix
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
    ../../modules/ssh.nix
    ../../modules/git.nix
    ../../modules/docker.nix
  ];
```

- [ ] **Step 3: Verify**

```bash
nix eval .#nixosConfigurations.pi.config.virtualisation.docker.enable
nix eval .#nixosConfigurations.pi.config.system.build.toplevel.drvPath
```

Expected: `true`, and a `.drv` path with no errors.

- [ ] **Step 4: Commit**

```bash
git add modules/docker.nix hosts/pi/default.nix
git commit -m "modules: enable docker"
```

---

## Task 9: `modules/dev-tools.nix` — gh, claude-code, VS Code Remote-SSH fix

**Files:**
- Create: `modules/dev-tools.nix`
- Modify: `hosts/pi/default.nix` (add import)

**Interfaces:**
- Consumes: nothing new.
- Produces: `gh`, `claude-code` (or its fallback), `programs.nix-ld.enable`, verified in Task 13.

- [ ] **Step 1: Check whether `claude-code` is packaged in the pinned nixpkgs**

```bash
nix eval nixpkgs#claude-code.pname 2>&1
```

If this prints `"claude-code"`, use the **primary** module body in Step 2. If it errors (`attribute 'claude-code' missing`), use the **fallback** module body instead.

- [ ] **Step 2 (primary — `claude-code` is packaged): Write `modules/dev-tools.nix`**

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.gh
    pkgs.claude-code
  ];

  programs.nix-ld.enable = true;
}
```

- [ ] **Step 2 (fallback — `claude-code` is not packaged): Write `modules/dev-tools.nix` instead**

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.gh
    pkgs.nodejs_22
  ];

  programs.nix-ld.enable = true;

  system.activationScripts.claude-code-npm = {
    text = ''
      su - ryan -c '${pkgs.nodejs_22}/bin/npm install -g --prefix ~/.npm-global @anthropic-ai/claude-code' || true
    '';
    deps = [ "users" ];
  };
}
```

If the fallback is used, also add `home.sessionPath = [ "$HOME/.npm-global/bin" ];` to `home/ryan/home.nix` in this same task, so the npm-installed binary is found on `PATH`.

- [ ] **Step 3: Wire the import**

```nix
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
    ../../modules/ssh.nix
    ../../modules/git.nix
    ../../modules/docker.nix
    ../../modules/dev-tools.nix
  ];
```

- [ ] **Step 4: Verify**

```bash
nix eval .#nixosConfigurations.pi.config.programs.nix-ld.enable
nix eval .#nixosConfigurations.pi.config.system.build.toplevel.drvPath
```

Expected: `true`, and a `.drv` path with no errors.

- [ ] **Step 5: Commit**

```bash
git add modules/dev-tools.nix hosts/pi/default.nix home/ryan/home.nix
git commit -m "modules: add gh, claude-code, nix-ld for VS Code Remote-SSH"
```

---

## Task 10: niri module — on-demand graphical session

**Files:**
- Create: `modules/niri/nixos.nix`
- Create: `modules/niri/home.nix`
- Create: `modules/niri/config.kdl`
- Create: `hosts/pi/niri.kdl`
- Modify: `hosts/pi/default.nix` (add import + `/etc/niri/host.kdl` placement)
- Modify: `home/ryan/home.nix` (import niri home module)

**Interfaces:**
- Consumes: nothing new.
- Produces: `niri-session` availability, verified manually in Task 13 (this is hardware/display behavior `nix eval` can't confirm).

- [ ] **Step 1: Write `modules/niri/nixos.nix`**

```nix
{ ... }:
{
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  programs.niri.enable = true;
}
```

- [ ] **Step 2: Write `modules/niri/config.kdl`**

Adapted from `BJSummerfield/nixcfg`'s `modules/niri/config.kdl`: same layout, cursor, and keybindings, with the 1Password-specific line and the `dynamic.kdl`/`binds.kdl`/`tests.kdl` includes removed (per Global Constraints). The `/etc/niri/host.kdl` include is kept.

```kdl
cursor {
    xcursor-size 32
}
hotkey-overlay {
    skip-at-startup
}
input {
    touchpad {
        natural-scroll
    }
}
gestures {
    hot-corners {
        off
    }
}
layout {
    gaps 10
    background-color "transparent"
    center-focused-column "on-overflow"
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
        proportion 0.8322
    }
    focus-ring {
        width 1
        active-color "#7fc8ff"
        inactive-color "#505050"
    }
    border {
        off
    }
}
prefer-no-csd
screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
blur {
    off
}
binds {
    Mod+Shift+Slash {
        show-hotkey-overlay
    }
    XF86AudioRaiseVolume allow-when-locked=true {
        spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"
    }
    XF86AudioLowerVolume allow-when-locked=true {
        spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"
    }
    XF86AudioMute allow-when-locked=true {
        spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"
    }
    XF86AudioMicMute allow-when-locked=true {
        spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"
    }
    XF86MonBrightnessUp allow-when-locked=true {
        spawn "brightnessctl" "s" "10%+"
    }
    XF86MonBrightnessDown allow-when-locked=true {
        spawn "brightnessctl" "s" "10%-"
    }
    Mod+Q {
        close-window
    }
    Mod+Tab {
        toggle-overview
    }
    Mod+Left {
        focus-column-left
    }
    Mod+Down {
        focus-window-down
    }
    Mod+Up {
        focus-window-up
    }
    Mod+Right {
        focus-column-right
    }
    Mod+H {
        focus-column-left
    }
    Mod+J {
        focus-window-down
    }
    Mod+K {
        focus-window-up
    }
    Mod+L {
        focus-column-right
    }
    Mod+Shift+Left {
        move-column-left
    }
    Mod+Shift+Down {
        move-window-down
    }
    Mod+Shift+Up {
        move-window-up
    }
    Mod+Shift+Right {
        move-column-right
    }
    Mod+Shift+H {
        move-column-left
    }
    Mod+Shift+J {
        move-window-down
    }
    Mod+Shift+K {
        move-window-up
    }
    Mod+Shift+L {
        move-column-right
    }
    Mod+Home {
        focus-column-first
    }
    Mod+End {
        focus-column-last
    }
    Mod+Ctrl+Home {
        move-column-to-first
    }
    Mod+Ctrl+End {
        move-column-to-last
    }
    Mod+Page_Down {
        focus-workspace-down
    }
    Mod+Page_Up {
        focus-workspace-up
    }
    Mod+U {
        focus-workspace-down
    }
    Mod+I {
        focus-workspace-up
    }
    Mod+Ctrl+Page_Down {
        move-column-to-workspace-down
    }
    Mod+Ctrl+Page_Up {
        move-column-to-workspace-up
    }
    Mod+Shift+Page_Down {
        move-workspace-down
    }
    Mod+Shift+Page_Up {
        move-workspace-up
    }
    Mod+WheelScrollDown cooldown-ms=150 {
        focus-workspace-down
    }
    Mod+WheelScrollUp cooldown-ms=150 {
        focus-workspace-up
    }
    Mod+1 {
        focus-workspace 1
    }
    Mod+2 {
        focus-workspace 2
    }
    Mod+3 {
        focus-workspace 3
    }
    Mod+4 {
        focus-workspace 4
    }
    Mod+5 {
        focus-workspace 5
    }
    Mod+Shift+1 {
        move-column-to-workspace 1
    }
    Mod+Shift+2 {
        move-column-to-workspace 2
    }
    Mod+Shift+3 {
        move-column-to-workspace 3
    }
    Mod+Shift+4 {
        move-column-to-workspace 4
    }
    Mod+Shift+5 {
        move-column-to-workspace 5
    }
    Mod+BracketLeft {
        consume-or-expel-window-left
    }
    Mod+BracketRight {
        consume-or-expel-window-right
    }
    Mod+Comma {
        consume-window-into-column
    }
    Mod+Period {
        expel-window-from-column
    }
    Mod+R {
        switch-preset-column-width
    }
    Mod+Shift+R {
        switch-preset-window-height
    }
    Mod+F {
        maximize-column
    }
    Mod+Shift+F {
        fullscreen-window
    }
    Mod+C {
        center-column
    }
    Mod+Minus {
        set-column-width "-10%"
    }
    Mod+Equal {
        set-column-width "+10%"
    }
    Mod+V {
        toggle-window-floating
    }
    Mod+Alt+1 {
        screenshot
    }
    Mod+Alt+2 {
        screenshot-screen
    }
    Mod+Alt+3 {
        screenshot-window
    }
    Mod+Escape allow-inhibiting=false {
        toggle-keyboard-shortcuts-inhibit
    }
    Mod+Shift+E {
        quit
    }
    Ctrl+Alt+Delete {
        quit
    }
    Mod+Shift+P {
        power-off-monitors
    }
}
include optional=true "/etc/niri/host.kdl"
```

- [ ] **Step 3: Write `modules/niri/home.nix`**

```nix
{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  home.packages = with pkgs; [
    alacritty
    fuzzel
    nautilus
    wl-clipboard
    xwayland-satellite
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
}
```

- [ ] **Step 4: Write `hosts/pi/niri.kdl`**

```kdl
// Host-specific niri output/window rules for `pi`.
// Empty for now — add output configuration here once the external
// monitor / Xreal glasses display mode is known (check with
// `niri msg outputs` after the first graphical session).
```

- [ ] **Step 5: Wire everything into `hosts/pi/default.nix`**

```nix
  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
    ../../modules/ssh.nix
    ../../modules/git.nix
    ../../modules/docker.nix
    ../../modules/dev-tools.nix
    ../../modules/niri/nixos.nix
  ];
```

Add, alongside the other host-level settings:

```nix
  environment.etc."niri/host.kdl".source = ./niri.kdl;
```

- [ ] **Step 6: Import the niri home-manager module in `home/ryan/home.nix`**

```nix
{ ... }:
{
  imports = [ ../../modules/niri/home.nix ];

  home.stateVersion = "25.11";
  home.username = "ryan";
  home.homeDirectory = "/home/ryan";

  programs.git = {
    enable = true;
    userName = "Ryan Lucas";
    userEmail = "rdlucas2@gmail.com";
  };
}
```

- [ ] **Step 7: Verify**

```bash
nix eval .#nixosConfigurations.pi.config.programs.niri.enable
nix eval .#nixosConfigurations.pi.config.system.build.toplevel.drvPath
```

Expected: `true`, and a `.drv` path with no errors. (Whether niri actually renders correctly on the external monitor/glasses can only be confirmed on real hardware — that check happens in Task 13.)

- [ ] **Step 8: Commit**

```bash
git add modules/niri hosts/pi home/ryan/home.nix
git commit -m "modules: add on-demand niri desktop session"
```

---

## Task 11: Bootstrap the Pi for its first flake-based switch

**Files:** none (remote setup only)

**Interfaces:**
- Consumes: the flake at `github.com/rdlucas2/nixcfg` (pushed in this task), SSH access as `nixos@192.168.0.71` (already working from earlier in this session).
- Produces: a clone of the repo on the Pi at `/home/nixos/nixcfg`, ready for `nixos-rebuild switch` in Task 13.

- [ ] **Step 1: Push everything built so far**

```bash
cd /home/ryan/_git/nixcfg
git push -u origin main
```

Expected: push succeeds (the remote `https://github.com/rdlucas2/nixcfg.git` already exists per Global Constraints).

- [ ] **Step 2: Clone the repo onto the Pi**

```bash
ssh nixos@192.168.0.71 "nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c git clone https://github.com/rdlucas2/nixcfg.git /home/nixos/nixcfg"
```

- [ ] **Step 3: Verify**

```bash
ssh nixos@192.168.0.71 "git -C /home/nixos/nixcfg log -1 --oneline"
```

Expected: prints the most recent commit from Task 10 (`modules: add on-demand niri desktop session`).

- [ ] **Step 4: Commit**

Nothing to commit — this task only sets up the remote clone.

---

## Task 12: Register the Pi's host age key and re-encrypt secrets

**Files:**
- Modify: `.sops.yaml`
- Modify: `secrets/secrets.yaml` (re-encrypted, same plaintext content)

**Interfaces:**
- Consumes: the Pi's existing SSH host key (already present — the system has been running since before this project started).
- Produces: `secrets/secrets.yaml` decryptable by the Pi at activation time via `sops.age.sshKeyPaths`' default (`/etc/ssh/ssh_host_ed25519_key`), which `modules/users.nix`'s `neededForUsers = true` secret depends on.

- [ ] **Step 1: Fetch the Pi's SSH host public key**

```bash
ssh nixos@192.168.0.71 "cat /etc/ssh/ssh_host_ed25519_key.pub"
```

Expected: a line like `ssh-ed25519 AAAA... root@nixos`. Copy it.

- [ ] **Step 2: Convert it to an age public key**

On the dev machine, substituting the key from Step 1:

```bash
echo "<PI_SSH_HOST_PUBKEY>" | nix shell nixpkgs#ssh-to-age --command ssh-to-age
```

Expected: prints an `age1...` value. Copy it.

- [ ] **Step 3: Add it to `.sops.yaml`**

Substituting the value from Step 2 in place of `<PI_HOST_AGE_PUBKEY>`:

```yaml
keys:
  - &dev_ryan <DEV_AGE_PUBKEY>
  - &host_pi <PI_HOST_AGE_PUBKEY>
creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *dev_ryan
          - *host_pi
```

(Keep the real `<DEV_AGE_PUBKEY>` value already in the file from Task 2 — only add the new `&host_pi` line and list entry.)

- [ ] **Step 4: Re-encrypt the secret for the new recipient**

```bash
nix shell nixpkgs#sops --command sops updatekeys secrets/secrets.yaml
```

Confirm `y` when prompted that the recipient list changed.

- [ ] **Step 5: Verify both keys can decrypt**

```bash
nix shell nixpkgs#sops --command sops --decrypt secrets/secrets.yaml
```

Expected: still prints `ryan-password: $6$...` (same hash as Task 3) — proves the dev key still works after the recipient list changed.

- [ ] **Step 6: Commit, push, and pull on the Pi**

```bash
git add .sops.yaml secrets/secrets.yaml
git commit -m "sops: register pi host age key"
git push
ssh nixos@192.168.0.71 "git -C /home/nixos/nixcfg pull"
```

Expected: the Pi's clone now has the updated `.sops.yaml` and `secrets/secrets.yaml`.

---

## Task 13: First deploy and full verification

**Files:** none (deployment + verification only)

**Interfaces:**
- Consumes: everything from Tasks 1–12.
- Produces: the running Pi switched onto the new flake-managed configuration — the deliverable of this entire plan.

- [ ] **Step 1: Dry-build from the Pi first**

```bash
ssh nixos@192.168.0.71 "cd /home/nixos/nixcfg && sudo nixos-rebuild dry-build --flake .#pi --extra-experimental-features 'nix-command flakes'"
```

Expected: completes without error, listing derivations to be built — confirms the whole config builds before committing to a real switch.

- [ ] **Step 2: Switch**

```bash
ssh nixos@192.168.0.71 "cd /home/nixos/nixcfg && sudo nixos-rebuild switch --flake .#pi --extra-experimental-features 'nix-command flakes'"
```

Expected: completes without error. The `nixos` account is untouched (`users.mutableUsers` defaults to `true` — see Global Constraints), so this SSH session should still work afterward even if something about the `ryan` account is wrong.

- [ ] **Step 3: Reboot and confirm it comes back up on extlinux/U-Boot as before**

```bash
ssh nixos@192.168.0.71 "sudo reboot"
```

Wait roughly 30–60 seconds, then:

```bash
timeout 5 bash -c 'echo > /dev/tcp/192.168.0.71/22' && echo "SSH back up"
```

- [ ] **Step 4: Verify SSH as `ryan` with the same key**

```bash
ssh -o BatchMode=yes ryan@192.168.0.71 "whoami && hostname"
```

Expected: `ryan` / `pi`.

- [ ] **Step 5: Verify dev tooling**

```bash
ssh ryan@192.168.0.71 "git --version && gh --version && claude --version && docker run hello-world"
```

Expected: version strings for each, and `docker run hello-world` prints Docker's standard "Hello from Docker!" message (proves the `docker` group membership from Task 5 and `virtualisation.docker.enable` from Task 8 both work).

- [ ] **Step 6: Verify the password secret decrypted correctly**

```bash
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no ryan@192.168.0.71 "echo login-with-password-worked"
```

When prompted, enter the password chosen in Task 3, Step 1. Expected: `login-with-password-worked` printed — confirms `sops` correctly decrypted `ryan-password` during activation and it's live on the account (not a locked/invalid hash).

- [ ] **Step 7: Verify the niri session manually**

At the Pi's own keyboard/monitor (not over SSH — this is a display-hardware check): log in as `ryan`, run `niri-session`, and confirm: the compositor starts on the external monitor, `Mod+Return`-equivalent or a manually spawned `alacritty` opens a terminal, `fuzzel` (bound to whatever launcher key you choose to test, or run `fuzzel` directly from an alacritty terminal) opens the app launcher, and `nautilus` opens a file browser window.

- [ ] **Step 8: Record the outcome**

If every check in Steps 4–7 passes, Phase 1 is complete against the spec's success criteria. If Step 7 reveals display issues specific to the external monitor or Xreal glasses, capture the output of `niri msg outputs` (run inside the niri session) and use it to fill in `hosts/pi/niri.kdl` (currently an intentionally empty stub from Task 10) in a follow-up change — this is expected polish, not a blocker for calling Phase 1 done.
