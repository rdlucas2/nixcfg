# Deploy Runbook

Practical rules for pushing a new config to a live host (the Pi in
particular), written after a WiFi-only deploy took the Pi off the network
mid-switch and deleted its fallback account in the same activation.

## 1. Prefer ethernet

Never deploy over the only link the deploy itself can reconfigure. If
`nixos-rebuild` is about to change networking (interfaces, wireless config,
firewall, etc.) and you are connected over the interface being changed, a
mistake or an unrelated bug can drop you with no way back in. Plug in
ethernet for deploys whenever possible; treat WiFi-only deploys as
best-effort, not something to rely on for recovery.

## 2. `test` before `switch`

Always activate with `test` first:

```
sudo NIX_CONFIG='extra-experimental-features = nix-command flakes' nixos-rebuild test --flake .#pi
```

`test` activates the new configuration immediately but does **not** make it
the boot default. If it breaks something, a power cycle reverts to the last
known-good generation with no manual intervention. Verify the host is still
reachable, SSH still works, and (if relevant) that you can still `sudo`
before doing anything else.

Only after that verification passes, run the same command with `switch`:

```
sudo NIX_CONFIG='extra-experimental-features = nix-command flakes' nixos-rebuild switch --flake .#pi
```

`switch` does the same activation but also sets the new generation as the
boot default.

## 3. Flags: what actually works on NixOS 25.11

- Plain `--extra-experimental-features nix-command flakes` is **not** a
  valid `nixos-rebuild` flag on NixOS 25.11 — the Python rewrite of
  `nixos-rebuild` rejects it outright.
- The working form is setting `NIX_CONFIG` in the environment, as shown
  above.

## 4. Offline rollback

`nixos-rebuild --rollback` **fails with no network**, because it tries to
fetch the flake registry first. If the host has no working network (e.g.
you're on physical console after a bad switch), don't use it. Instead:

```
sudo nix-env --rollback -p /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Alternatively, reboot and pick a previous generation from the U-Boot /
extlinux boot menu.

## 5. Pre-switch checklist

Before running `switch` (or even `test`) against a real host, confirm:

- [ ] The config still declares the network interface(s) you are connected
      over (wired and/or wireless, as applicable). A `nixos-rebuild switch`
      replaces the entire system closure — anything providing networking in
      the running generation that is not declared in the new config is
      destroyed the moment the new generation activates.
- [ ] A fallback account — `root` — has a password set
      (`users.users.root.hashedPasswordFile`, sourced from sops). Any
      declaratively-created normal user that disappears from the config is
      deleted by NixOS on activation; `root` cannot be removed this way, so
      it is the account that must always be reachable if everything else
      goes wrong.
