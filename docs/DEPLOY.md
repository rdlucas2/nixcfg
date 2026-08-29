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

## 3. Which branch gets which verb

The verb follows the branch, so that the boot default is only ever set
from reviewed, merged config:

| Where you are | Verb | Why |
|---|---|---|
| Feature branch | `test` | Activates for evaluation, but leaves the boot default alone. A reboot returns to whatever `main` last set. |
| `main`, after merge | `switch` | Activates *and* makes it the boot default. |

`test` is not a dry run. It fully activates: services restart, users are
created and deleted, networking reconfigures. The single guarantee it
gives is that a power cycle undoes it — which is precisely the recovery
path that still works when a bad config has cost you the network and
the ability to log in. That is why branch work uses it.

Use `boot` only for changes that cannot take effect without a reboot
anyway (a kernel or initrd change): it sets the boot default without
disturbing the running system. `build` is the genuinely inert one — it
compiles the config and activates nothing.

Note that `test` leaves no trace in `/nix/var/nix/profiles/system`, so
testing repeatedly does not accumulate generations. To tell which kind
of activation the running system came from:

```
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
```

Equal means the last activation was a `switch`; different means a `test`
is currently active and will vanish on reboot.

## 4. Deploying from the dev machine instead of the Pi

`git pull` on the Pi is not required. `nixos-rebuild` can evaluate
locally and hand both the build and the activation to the Pi:

```
nixos-rebuild test --flake .#pi \
  --build-host ryan@192.168.0.71 \
  --target-host ryan@192.168.0.71 \
  --ask-elevate-password
```

`--build-host` must point at the Pi: evaluating an aarch64 config on an
x86_64 machine works fine, but *building* it there does not without
emulation or a cross setup.

The flake gotcha applies here too — flakes only see files git knows
about, so a newly created module that has not been `git add`-ed is
invisible and evaluation fails with "path ... is not tracked by Git".
Staging is enough; it does not have to be committed.

## 5. Flags: what actually works on NixOS 25.11

- Plain `--extra-experimental-features nix-command flakes` is **not** a
  valid `nixos-rebuild` flag on NixOS 25.11 — the Python rewrite of
  `nixos-rebuild` rejects it outright.
- The working form is setting `NIX_CONFIG` in the environment, as shown
  above.

## 6. Offline rollback

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
