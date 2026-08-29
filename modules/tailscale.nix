{ config, ... }:
{
  services.tailscale = {
    enable = true;

    # "client" accepts routes advertised by other nodes and allows using an
    # exit node. "server" additionally turns on IP forwarding so this host can
    # advertise routes or act as an exit node itself — not wanted here, and it
    # sets kernel sysctls that are worth not enabling without a reason.
    useRoutingFeatures = "client";

    # Opens the UDP port tailscaled listens on so peers can establish direct
    # connections. Without it traffic still works, but falls back to relaying
    # through DERP servers, which is slower and adds latency.
    openFirewall = true;
  };

  # This is the line that makes "reach things running on this machine" work.
  # NixOS enables a firewall by default, so anything this host listens on is
  # blocked unless a port is explicitly opened. Trusting the tailscale
  # interface exempts tailnet traffic from those rules, so a service is
  # reachable from your own devices without also being exposed to the LAN —
  # no per-service firewall holes to remember when adding something new.
  #
  # The trade-off is deliberate: every device on the tailnet can reach every
  # listening port on this host. That is the intent for a personal tailnet;
  # it would be the wrong default on a shared one, where per-port rules or
  # tailnet ACLs belong instead.
  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

  # Authentication is deliberately not declared here. Pre-shared auth keys
  # expire (90 days at most) and would need rotating in sops forever, which is
  # the wrong shape for a machine meant to stay joined. Run `sudo tailscale up`
  # once, interactively; the node key persists in /var/lib/tailscale across
  # reboots and rebuilds.
}
