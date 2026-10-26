# ADR-0008: Tailscale operator only

- Status: accepted
- Date: 2026-10-26

## Context

Remote access is the exception: the operator is usually on the home network. Running a
Tailscale client on Proxmox would add an out-of-band path, but it is another non-Kubernetes
component to maintain.

## Decision

- Run the Tailscale Kubernetes Operator in-cluster.
- A two-replica `Connector` advertises `192.168.178.0/24` while the cluster is up, so admin
  services keep their LAN-only Traefik route instead of each getting a Tailscale Ingress.
  Public DNS for `home.jonasseidl.com` resolves to `192.168.178.243` on and off the LAN.
- Enable the API server proxy so `kubectl` works through the tailnet without a kubeconfig
  holding a client certificate.
- Do not install Tailscale on Proxmox by default.
- If remote recovery access is required while the cluster is down, use the FRITZ!Box
  WireGuard VPN as the emergency path.

## Consequences

- Remote service access follows the cluster's availability.
- No Tailscale component outside Kubernetes except the router's built-in VPN.
- The Tailscale OAuth client secret comes from BSM via ESO.
- Subnet routes must be approved once per node. Prefer an `autoApprovers` entry for
  `tag:k8s` in the tailnet policy so a rebuilt connector does not need a manual click.
- The OAuth client is only permitted to request `tag:k8s`, so the operator shares that tag
  with the proxies. The operator/proxy split (`tag:k8s-operator`) can be restored once the
  credential is allowed to request it; with the current allow-all ACL the difference is
  only cosmetic.
