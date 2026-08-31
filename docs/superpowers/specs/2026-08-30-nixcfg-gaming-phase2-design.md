# Phase 2 — Gaming PC (`gaming`) design

Status: approved for planning
Date: 2026-08-30
Follows: `2026-08-28-nixcfg-pi-phase1-design.md`

## 1. Purpose

Replace Windows on the desktop with NixOS, managed from the same flake as
the Pi. Windows stays installed and bootable throughout, so the migration
is reversible and can happen game by game rather than all at once.

The Pi proved the tooling. This host is where the daily work actually
moves: gaming, streaming, media, and the same development environment.

## 2. Hardware (verified, not assumed)

Read from the running Windows install via WSL interop, not from memory or
model numbers.

| Component | Detail | Linux support |
|---|---|---|
| CPU | AMD Ryzen 7 3700X, 8C/16T (Matisse/Zen 2) | native |
| Board | ASRock B550M/ac, AMI BIOS P2.20, UEFI | native |
| RAM | 16 GB (2×8), rated 3200 C16, **running at 2667** | see §12 |
| GPU | AMD Radeon RX 6800, PCI `1002:73BF` (Navi 21) | `amdgpu`, open source |
| WiFi | Intel Dual Band Wireless-AC 3168, PCI `8086:24FB` | `iwlwifi` + linux-firmware |
| Bluetooth | Intel, USB `8087:0AA7` | `btintel` |
| Ethernet | Realtek, PCI `10EC:8168` (present, unplugged) | `r8169` |
| Audio | Realtek `10EC:0B00`, AMD HDMI `1002:AA01`, 2× USB audio, Logitech mic | `snd_hda_intel`, `snd-usb-audio` |
| Display 1 | Sceptre O34, 3440×1440 @ 144 Hz (max 165), **DisplayPort** | native |
| Display 2 | HP 27f, 1920×1080 @ 60 Hz, **HDMI** | native |
| Disk 0 | Samsung SSD 870 QVO 1 TB, SATA, GPT — Windows, 55 GB free | untouched |
| Disk 1 | Seagate ST3000DM007 3 TB, SATA, GPT — 2.1 TB free | ntfs, read-only |
| M.2 | **1× Hyper M.2, 2280, PCIe Gen4 ×4, currently empty** | destination |

The GPU is the decisive fact: RDNA2 on `amdgpu` needs no proprietary
driver, has mature Wayland support, and uses RADV for Vulkan. This is the
configuration Linux gaming works best on.

The WiFi is the second: Intel `iwlwifi` works in the installer and after,
so **ethernet is not required** despite being impractical to run to this
room. The ethernet port stays as a break-glass option.

## 3. Decisions

| Decision | Choice | Why |
|---|---|---|
| NixOS location | New NVMe in the empty M.2 slot | Windows untouched; SSD has only 55 GB free; the 3 TB is a slow spinning disk |
| Windows | Kept, bootable | Fallback during migration; games can move gradually |
| Bootloader | systemd-boot on the NVMe's own ESP | Windows keeps its own ESP on its own disk; nothing NixOS does can break the fallback |
| OS selection | Firmware boot menu (F11) | No single bootloader owning both OSes |
| Filesystem | ext4 | Matches the Pi; snapshots not required |
| Repo structure | Flat `modules/`, per-host import lists | Two hosts do not justify a profile layer; migration to profiles is mechanical later |
| Sessions | Plasma 6 + gamescope + niri | Right tool per task; one Steam library shared by all three |
| Networking | NetworkManager (not the Pi's wpa_supplicant) | Desktop wants a GUI and roaming; the Pi is headless |

## 4. Repo structure

Approach A: `modules/*.nix` stay flat, each host imports what it needs.
`hosts/pi/default.nix` and `hosts/gaming/default.nix` reference the same
files; each machine evaluates only its own list.

**The rule that keeps this healthy:** shared modules contain only what is
genuinely universal. Anything that varies lives in the host file. A
`lib.mkForce` appearing in a host file is the signal that a shared module
asserted something it should not have — the fix is to lift the value out,
never to add the force.

**Migration path if a third host appears:** create `profiles/*.nix`
holding the shared import list and have hosts import profiles. Nothing
about the modules changes. Not done now — two hosts do not justify it, and
the third machine's needs are unknown.

### 4.1 Prep (separate commit, before any new host)

Two Phase 1 modules carry Pi-specific values that would be wrong here:

- `modules/users.nix` — `uid = 1001` is an artifact of adopting an
  existing Pi install. Remove from the shared module; set it in
  `hosts/pi/default.nix`. A fresh install gets the default 1000.
- `modules/niri/nixos.nix` — `GSK_RENDERER = "gl"` works around the Pi's
  incomplete v3dv Vulkan driver. On an RX 6800 with RADV, forcing GL is a
  pessimization. Move to `hosts/pi/default.nix`.

`modules/audio.nix` and `modules/bluetooth.nix` read Pi-specific in their
comments but are generic in effect; the Bluetooth autoconnect service
already matches on the Audio Sink UUID rather than a MAC, so it transfers
unchanged.

**Acceptance:** the Pi's `system.build.toplevel` derivation hash is
unchanged by this commit. The refactor must be provably behaviour-preserving.

## 5. Storage and boot

```
nvme0n1  (new, 2 TB)         sda  Samsung 870 QVO      sdb  Seagate 3 TB
├─ p1  1 GB  vfat  /boot     └─ Windows, untouched     └─ media
└─ p2  rest  ext4  /            (own ESP, own disk)       (ntfs, ro)
```

- GPT, UEFI, `boot.loader.systemd-boot.enable = true`,
  `boot.loader.efi.canTouchEfiVariables = true`.
- `boot.loader.systemd-boot.configurationLimit` set so the 1 GB ESP cannot
  fill with old kernels.
- Windows NTFS partitions mounted **read-only** at `/mnt/windows` and
  `/mnt/data` via `ntfs3g`. Read-only is deliberate: Windows fast-startup
  leaves NTFS in a hibernated state, and writing to it corrupts the
  filesystem.
- Steam library lives on the NVMe under `$HOME`. Because it is user data,
  all three sessions share one copy — the gamescope session launches the
  same Steam install as Plasma.

Drive purchase: any M.2 2280 NVMe. Gen4 preferred since the socket
supports it and there is only one, but Gen3 is acceptable — real-world
difference for game loading and Nix builds is small.

## 6. Graphics

- `hardware.graphics.enable` with `enable32Bit` — Steam and Proton need
  32-bit userspace.
- Mesa/RADV. No proprietary driver, no `hardware.nvidia` equivalent needed.
- `boot.initrd.kernelModules = [ "amdgpu" ]` for early KMS.

## 7. Sessions

Three, offered by greetd/tuigreet via `--sessions` pointing at the
wayland-sessions and xsessions directories:

1. **Plasma 6** — desktop and gaming. Best current VRR/HDR handling,
   Dolphin as a familiar file manager.
2. **Steam Big Picture** — `programs.steam.gamescopeSession.enable`.
   Console-style, same library.
3. **niri** — coding. Module reused from Phase 1 unchanged; only the
   host's output block differs.

**Known limitation:** Plasma stores its display arrangement in user state
via kscreen, not declaratively. The Plasma monitor layout is set once in
its settings GUI and persists there; it will not live in this repo. Only
the niri session's layout is declarative.

## 8. Displays

`hosts/gaming/niri.kdl`, keyed on EDID identity as on the Pi:

| Output | Connection | Mode | Position |
|---|---|---|---|
| Sceptre O34 | DisplayPort | 3440×1440@144, VRR enabled | `0,0` |
| HP 27f | HDMI | 1920×1080@60 | `3440,0` |

Exact EDID strings to be read with `niri msg outputs` on first boot, as
was done for the Pi — not guessed from the Windows-reported names.

## 9. Networking

`modules/network-manager.nix`, imported by `gaming` only.
`modules/wifi.nix` stays Pi-only. This is the §4 rule working as intended,
not a compromise: a headless Pi and a desktop have genuinely different
needs.

## 10. Secrets

The new host needs its own age key derived from its SSH host key, added as
a recipient in `.sops.yaml`, after which existing secrets are re-encrypted.

**Ordering constraint:** the key does not exist until the machine is
installed. Sequence is install → harvest host key → add recipient →
re-encrypt → deploy secrets-dependent config. The first deploy therefore
cannot include sops-backed secrets.

## 11. Applications

| Category | Packages |
|---|---|
| Gaming | steam, gamescope, gamemode, mangohud, protontricks, protonup-qt |
| Launchers | heroic (Epic + GOG), lutris, bottles |
| Voice/chat | discord, **teamspeak6-client** |
| Streaming | sunshine (replaces Parsec), obs-studio |
| Emulation | retroarch, dolphin-emu, pcsx2, rpcs3 |
| Media | jellyfin-media-player, mpv |
| Secure comms | keybase, keybase-gui, kbfs |
| Dev (reused) | git, gh, claude-code, vscode, vim, docker |
| Shared (reused) | tailscale, bluetooth, audio, greetd, users, ssh |

Unfree packages requiring an `allowUnfreePredicate` entry: `steam`,
`steam-unwrapped`, `discord`, `teamspeak6-client`, `vscode`, `claude-code`.

## 12. Known limitations and non-goals

- **Streamlabs Desktop does not exist for Linux.** Not in nixpkgs, not
  shipped by Streamlabs for any distro. OBS Studio — which Streamlabs
  Desktop is a fork of — replaces it. Streamlabs alerts and overlays
  continue to work as OBS browser sources, so the account and widgets
  survive; only the application shell changes.
- **TeamSpeak 3 and 5 no longer exist in nixpkgs.** Only
  `teamspeak6-client` (6.0.0-beta4.1), x86_64-only. It cannot run on the
  Pi: the derivation fetches a single tarball with no architecture
  selection because TeamSpeak publishes no ARM build.
- **DuckStation was removed from nixpkgs.** RetroArch's Beetle PSX core
  covers PS1 emulation.
- **Plasma's display layout is not declarative** (§7).
- **RAM runs at 2667 rather than its rated 3200.** DOCP/XMP is not enabled
  in BIOS. Unrelated to NixOS, but a free performance gain worth taking
  while the case is open.

## 13. Open items

1. **Secure Boot state** — `Confirm-SecureBootUEFI` requires an elevated
   PowerShell and has not been run. If enabled, either disable it in BIOS
   (simple) or adopt lanzaboote (complex). Must be settled before install.
2. **M.2 physical access** — the socket is confirmed present and empty,
   but on a microATX board with an RX 6800 the GPU may need removing to
   reach it. Confirm on opening the case.
3. **NVMe purchase** — model and capacity not yet chosen; 2 TB recommended.

## 14. Out of scope

- Migrating Windows game saves (manual, per-game, via the read-only mounts)
- VR
- Making the media server at 192.168.0.44 a NixOS host — a plausible third
  machine, and the point at which §4's profile migration would earn its
  keep, but not part of this work.
