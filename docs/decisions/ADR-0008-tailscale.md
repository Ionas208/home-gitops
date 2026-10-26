# ADR-0008: Tailscale operator only

- Status: accepted
- Date: 2026-10-26

## Context

Remote access is the exception: the operator is usually on the home network. Running a
Tailscale client on Proxmox would add an out-of-band path, but it is another non-Kubernetes
component to maintain.

## Decision

- Run the Tailscale Kubernetes Operator in-cluster.
- Use Tailscale Ingress/annotations for admin services.
- Optionally run a `Connector` CRD as a subnet router for Proxmox/QNAP access while the
  cluster is up.
- Do not install Tailscale on Proxmox by default.
- If remote recovery access is required while the cluster is down, use the FRITZ!Box
  WireGuard VPN as the emergency path.

## Consequences

- Remote service access follows the cluster's availability.
- No Tailscale component outside Kubernetes except the router's built-in VPN.
- The Tailscale OAuth client secret comes from BSM via ESO.
