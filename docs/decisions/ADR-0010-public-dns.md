# ADR-0010: Public DNS-only records for internal names

- Status: accepted
- Date: 2026-10-26
- Supersedes: ADR-0003

## Context

ADR-0003 put the LAN resolver inside the cluster. That made the LAN's only resolver
depend on a single Proxmox host, three VMs, the control plane, the CNI, MetalLB, and
a pod. Any of those failing would stop name resolution for the whole LAN while the
internet itself was unaffected. The FRITZ!Box offers a single DNS field, so no
secondary resolver could be handed out to clients.

The names it served point at the Traefik VIP, which lives in the same cluster. When
the cluster is down those names are useless anyway, so the in-cluster resolver added
no availability to internal names while actively breaking external resolution.

Alternatives considered and rejected: a resolver in an LXC on the Proxmox host, on a
single-board computer, or on the NAS. Each is still a server on the LAN that can fail,
and the requirement is that internet resolution survives any local failure.

## Decision

Publish internal names as ordinary Cloudflare records, **DNS-only** (proxy off):

- `home.jonasseidl.com` A `<TRAEFIK_VIP>`
- `*.home.jonasseidl.com` A `<TRAEFIK_VIP>`

Remove the in-cluster resolver entirely. Clients keep using the FRITZ!Box, which
forwards to the provider exactly as it does for every other name.

## Consequences

- No LAN DNS dependency on the cluster or on the Proxmox host. Internet resolution
  survives any local failure, which is the whole point.
- The FRITZ!Box drops upstream answers that contain private addresses, so
  `home.jonasseidl.com` must be listed as a DNS rebind-protection exception. Its
  exception list covers subdomains.
- The Traefik VIP is publicly visible. It is RFC1918 and unroutable from outside;
  off-LAN clients receive an address they cannot reach and TLS fails. Hostnames are
  already public through Certificate Transparency.
- Internal and public names are no longer separated. This supersedes the
  "no public wildcard" rule in ADR-0003. The wildcard stays scoped to `home`, so the
  apex and other subdomains keep their proxied, tunnel-backed records.
- A new service needs no DNS change, matching the wildcard certificate.
- The zone is two records created through the Cloudflare API, not Git. Moving them
  into OpenTofu would restore declarative management if that becomes important.
