# ADR-0003: In-cluster LAN DNS with CoreDNS

- Status: superseded by ADR-0010
- Date: 2026-10-26
- Superseded: 2026-10-26, before the in-cluster resolver became the LAN default. The
  cluster must not be the LAN's only resolver; see ADR-0010.

## Context

The lab needs wildcard internal DNS (`*.home.jonasseidl.com`) pointing at the Traefik VIP.
The FRITZ!Box cannot provide wildcard records. A local resolver is required.

AdGuard Home was considered and rejected: it adds a UI, ad-blocking, a PVC with runtime
configuration, and more moving parts than the requirement justifies. The lab does not
need network-wide ad-blocking.

## Decision

Run a second CoreDNS instance in Kubernetes as `dns/lan-dns`:

- authoritative for `home.jonasseidl.com`
- wildcard `*.home.jonasseidl.com` -> Traefik VIP
- explicit records for Proxmox, QNAP, and Talos hosts
- forwards public queries upstream
- MetalLB LoadBalancer IP for UDP/TCP 53
- DHCP remains on the FRITZ!Box

The Talos-managed `kube-system/coredns` remains separate and untouched.

## Consequences

- DNS configuration is fully declarative in Git.
- No UI or ad-blocking.
- If the cluster is down, LAN DNS is down; clients need a secondary DNS and should use
  IPs for Proxmox/QNAP during recovery.
- Proxmox and Talos host DNS must not depend on `lan-dns`.
- No public wildcard; internal and public names are kept separate.
