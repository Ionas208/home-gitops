# Phase 0 checklist

Phase 0 is documentation only. This checklist records what is decided and what is
deliberately deferred to the phase where it can be executed.

## Decisions recorded

- [x] repository topology
- [x] public repositories and no-secrets rule
- [x] one control plane + two workers, control plane schedulable
- [x] no fake HA; rebuild on new hardware
- [x] in-cluster CoreDNS for LAN DNS
- [x] DHCP stays on the FRITZ!Box; no ad-blocking
- [x] app-of-apps with self-managed Argo CD
- [x] Bitwarden Secrets Manager + External Secrets Operator
- [x] local-path + QNAP NFS storage split
- [x] Cloudflare Tunnel for public ingress
- [x] Tailscale operator only; no Tailscale client on Proxmox
- [x] public repo CI policy with GitHub-hosted runners for untrusted PRs
- [x] explicit phase gates

## Documented targets

- [x] hardware inventory
- [x] address placeholders and network design
- [x] DNS and TLS flows
- [x] public/internal ingress split
- [x] storage and backup strategy
- [x] QNAP model, disks, RAID, capacity
- [x] bootstrap sequence for Phase 1
- [x] application onboarding and restore runbooks

## Deferred until their phase

- [ ] real LAN addresses and VLAN/network plan (Phase 1)
- [ ] Proxmox install and API token (Phase 1)
- [ ] OpenTofu and Talos implementation (Phase 1)
- [ ] Argo CD bootstrap and root Application (Phase 1)
- [ ] MetalLB/Traefik/CoreDNS/cert-manager/ESO implementation (Phase 2)
- [ ] Cloudflare Tunnel and Access setup (Phase 2)
- [ ] QNAP NFS, snapshots, HBS 3 offsite copy (Phase 2-3)
- [ ] Tailscale OAuth and ACLs (Phase 2)
- [ ] portfolio and Strava MCP images (Phase 3)
- [ ] ARC and Renovate (Phase 3)
- [ ] UPS and graceful shutdown (Phase 4)
- [ ] new server rebuild (Phase 4)

## Exit criteria

- [x] architecture and constraints written down
- [x] decisions and open questions recorded
- [x] Phase 1 sequence clear enough to execute
- [x] no implementation files committed to the repositories
